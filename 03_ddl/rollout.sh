#!/bin/bash
set -e

PWD=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source $PWD/../functions.sh
source_bashrc

GEN_DATA_SCALE=$1
EXPLAIN_ANALYZE=$2
RANDOM_DISTRIBUTION=$3
MULTI_USER_COUNT=$4
SINGLE_USER_ITERATIONS=$5
SMALL_STORAGE=$7
MEDIUM_STORAGE=$8
LARGE_STORAGE=$9
GEN_DATA_DIR=${12}
DATABASE_TYPE=${20}


if [[ "$GEN_DATA_SCALE" == "" || "$EXPLAIN_ANALYZE" == "" || "$RANDOM_DISTRIBUTION" == "" || "$MULTI_USER_COUNT" == "" || "$SINGLE_USER_ITERATIONS" == "" ]]; then
	echo "You must provide the scale as a parameter in terms of Gigabytes, true/false to run queries with EXPLAIN ANALYZE option, true/false to use random distrbution, multi-user count, and the number of sql iterations."
	echo "Example: ./rollout.sh 100 false false 5 1"
	exit 1
fi

MARS2_ENCODING_MINMAX=""
if [ "$DATABASE_TYPE" == "matrixdb" ]; then
  if [[ "$GEN_DATA_SCALE" -lt "1000" ]]; then
    MARS2_ENCODING_MINMAX="encoding(minmax)"
  else
    MARS2_ENCODING_MINMAX="encoding(minmax,compresstype=zstd,compresslevel=1)"
  fi
fi

step=ddl
init_log $step
get_version

if [[ "$VERSION" == *"gpdb"* ]]; then
	filter="gpdb"
elif [ "$VERSION" == "postgresql" ]; then
	filter="postgresql"
else
	echo "ERROR: Unsupported VERSION $VERSION!"
	exit 1
fi

#Create tables
for i in $(ls $PWD/*.$filter.*.sql); do
	id=$(echo $i | awk -F '.' '{print $1}')
	schema_name=$(echo $i | awk -F '.' '{print $2}')
	table_name=$(echo $i | awk -F '.' '{print $3}')

	if [ "$filter" == "gpdb" ]; then
		if [ "$RANDOM_DISTRIBUTION" == "true" ]; then
			DISTRIBUTED_BY="DISTRIBUTED RANDOMLY"
		else
			for z in $(cat $PWD/distribution.txt); do
				table_name2=$(echo $z | awk -F '|' '{print $2}')
				if [ "$table_name2" == "$table_name" ]; then
					distribution=$(echo $z | awk -F '|' '{print $3}')
				fi
			done
			DISTRIBUTED_BY="DISTRIBUTED BY (""$distribution"")"
		fi

		if [[ "$SMALL_STORAGE" != *"mars2"* && "$MEDIUM_STORAGE" != *"mars2"* && "$LARGE_STORAGE" != *"mars2"* ]]; then
		  CREATE_EXTENSION=""
			CREATE_MARS2_BTREE_INDEX=""
		else
		  CREATE_EXTENSION="CREATE EXTENSION IF NOT EXISTS matrixts"
			CREATE_MARS2_BTREE_INDEX=""
			for z in $(cat $PWD/mars2_btree_index.txt); do
				table_name2=$(echo $z | awk -F '|' '{print $2}')
				storage_size=$(echo $z | awk -F '|' '{print $3}')
				if [[ "$table_name2" == "$table_name" && ${!storage_size} = *"mars2"* ]]; then
				    CREATE_MARS2_BTREE_INDEX="CREATE INDEX idx_$table_name ON tpch.$table_name USING mars2_btree($(echo $z | awk -F '|' '{print $4}')) $(echo $z | awk -F '|' '{print $5}')"
				fi
			done
		fi
	else
		DISTRIBUTED_BY=""
		CREATE_EXTENSION=""
		CREATE_MARS2_BTREE_INDEX=""
	fi

	echo "psql -v ON_ERROR_STOP=1 -q -a -P pager=off -f $i -v SMALL_STORAGE=\"$SMALL_STORAGE\" -v MEDIUM_STORAGE=\"$MEDIUM_STORAGE\" -v LARGE_STORAGE=\"$LARGE_STORAGE\" -v DISTRIBUTED_BY=\"$DISTRIBUTED_BY\" -v CREATE_MARS2_BTREE_INDEX=\"$CREATE_MARS2_BTREE_INDEX\" -v CREATE_EXTENSION=\"$CREATE_EXTENSION\""
	psql -v ON_ERROR_STOP=1 -q -a -P pager=off -f $i -v SMALL_STORAGE="$SMALL_STORAGE" -v MEDIUM_STORAGE="$MEDIUM_STORAGE" -v LARGE_STORAGE="$LARGE_STORAGE" -v DISTRIBUTED_BY="$DISTRIBUTED_BY" -v CREATE_MARS2_BTREE_INDEX="$CREATE_MARS2_BTREE_INDEX" -v CREATE_EXTENSION="$CREATE_EXTENSION" -v MARS2_ENCODING_MINMAX=$MARS2_ENCODING_MINMAX

done

#external tables are the same for all gpdb
if [ "$filter" == "gpdb" ]; then
	for i in $(ls $PWD/*.ext_tpch.*.sql); do
		start_log

		id=$(echo $i | awk -F '.' '{print $1}')
		schema_name=$(echo $i | awk -F '.' '{print $2}')
		table_name=$(echo $i | awk -F '.' '{print $3}')

		counter=0
		if [ "$VERSION" == "gpdb_6" -o "$VERSION" == "gpdb_7" ]; then
			for x in $(psql -v ON_ERROR_STOP=1 -q -A -t -c "select rank() over (partition by g.hostname order by g.datadir), g.hostname from gp_segment_configuration g where g.content >= 0 and g.role = 'p' order by g.hostname"); do
				CHILD=$(echo $x | awk -F '|' '{print $1}')
				EXT_HOST=$(echo $x | awk -F '|' '{print $2}')
				PORT=$(($GPFDIST_PORT + $CHILD))

				if [ "$counter" -eq "0" ]; then
					LOCATION="'"
				else
					LOCATION+="', '"
				fi
				LOCATION+="gpfdist://$EXT_HOST:$PORT/""$table_name.tbl*"

				counter=$(($counter + 1))
			done
		else
			for x in $(psql -v ON_ERROR_STOP=1 -q -A -t -c "select rank() over (partition by g.hostname order by p.fselocation), g.hostname from gp_segment_configuration g join pg_filespace_entry p on g.dbid = p.fsedbid join pg_tablespace t on t.spcfsoid = p.fsefsoid where g.content >= 0 and g.role = 'p' and t.spcname = 'pg_default' order by g.hostname"); do
				CHILD=$(echo $x | awk -F '|' '{print $1}')
				EXT_HOST=$(echo $x | awk -F '|' '{print $2}')
				PORT=$(($GPFDIST_PORT + $CHILD))

				if [ "$counter" -eq "0" ]; then
					LOCATION="'"
				else
					LOCATION+="', '"
				fi
				LOCATION+="gpfdist://$EXT_HOST:$PORT/""$table_name.tbl*"

				counter=$(($counter + 1))
			done
		fi
		LOCATION+="'"
		echo "psql -v ON_ERROR_STOP=1 -q -a -P pager=off -f $i -v LOCATION=\"$LOCATION\""
		psql -v ON_ERROR_STOP=1 -q -a -P pager=off -f $i -v LOCATION="$LOCATION" 

		log
	done
fi

end_step $step
