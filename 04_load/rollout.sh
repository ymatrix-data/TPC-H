#!/bin/bash
set -e

echo "############################################################################"
echo "Load data"
echo "############################################################################"
GEN_DATA_DIR=${12}
EXT_HOST_DATA_DIR=${13}
ADD_FOREIGN_KEY=${16}
DATABASE_TYPE=${20}
LOAD_DATA_TYPE=${21}

PWD=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source $PWD/../functions.sh
source_bashrc

GREENPLUM_PATH=$6

step=load
init_log $step

if [ "$ADMIN_USER" == "" ]; then
  ADMIN_USER=$(whoami)
fi

ADMIN_HOME=$(eval echo ~$ADMIN_USER)

get_version
if [[ "$VERSION" == *"gpdb"* ]]; then
	filter="gpdb"
elif [ "$VERSION" == "postgresql" ]; then
	filter="postgresql"
else
	echo "ERROR: Unsupported VERSION $VERSION!"
	exit 1
fi

function do_mxgate_import()
{
    MASTER_HOST=$(psql -v ON_ERROR_STOP=1 -AXtc "SELECT DISTINCT hostname FROM gp_segment_configuration WHERE role = 'p' AND content = -1")
    if [ "$MASTER_HOST" == "" ];then
          echo "ERROR: Unable to get matrixdb master host."
          exit 1
        fi
    MASTER_PORT=$PGPORT
    if [ "$MASTER_PORT" == "" ];then
      echo "ERROR: Unable to determine PGPORT environment variable.  Be sure to have this set for the mxadmin user."
      exit 1
    fi
    CORES=$(get_cpu_cores_num)
    echo "copy mxgate load data scripts to the primary segment"
    for i in $(psql -v ON_ERROR_STOP=1 -q -AXtc "select rank() over (partition by g.hostname order by g.datadir), g.hostname, g.datadir from gp_segment_configuration g where g.content >= 0 and g.role = 'p' order by g.hostname"); do
      SEGMENT_HOST=$(echo $i | awk -F '|' '{print $2}')
      PRIMARY_DATA_PATH=$(echo $i | awk -F '|' '{print $3}')
      GEN_DATA_PATH=$PRIMARY_DATA_PATH/pivotalguru
      echo "scp $PWD/mxgate_load.sh $ADMIN_USER@$SEGMENT_HOST:$PRIMARY_DATA_PATH/"
      scp $PWD/mxgate_load.sh $ADMIN_USER@$SEGMENT_HOST:$PRIMARY_DATA_PATH/
	  scp $PWD/mxgate_run.sh $ADMIN_USER@$SEGMENT_HOST:$PRIMARY_DATA_PATH/
      if [ "$PGUSER" == "" ]; then
        PGUSER=$ADMIN_USER
      fi
      if [ "$PGDATABASE" == "" ]; then
        PGDATABASE=$PGUSER
      fi
	  echo "ssh -n -f $SEGMENT_HOST \"bash -c 'source $GREENPLUM_PATH; cd $PRIMARY_DATA_PATH/; ./mxgate_run.sh $PGDATABASE $MASTER_HOST $MASTER_PORT $GEN_DATA_PATH $CORES $PGUSER'\""
	  status=$(ssh -n -f $SEGMENT_HOST "bash -c 'source $GREENPLUM_PATH; cd $PRIMARY_DATA_PATH/; ./mxgate_run.sh $PGDATABASE $MASTER_HOST $MASTER_PORT $GEN_DATA_PATH $CORES $PGUSER'")
	  if [ "$status" != "" ]; then
	  	echo "ERROR: Loading data by mxgate failed : [$status]"
	  	exit 1
	  fi  
    done
}

copy_script()
{
	echo "copy the start and stop scripts to the hosts in the cluster"
	for i in $(cat $PWD/../segment_hosts.txt); do
		echo "scp start_gpfdist.sh stop_gpfdist.sh $ADMIN_USER@$i:$EXT_HOST_DATA_DIR//"
		scp $PWD/start_gpfdist.sh $PWD/stop_gpfdist.sh $ADMIN_USER@$i:$EXT_HOST_DATA_DIR/
	done
}
stop_gpfdist()
{
	echo "stop gpfdist on all ports"
	for i in $(cat $PWD/../segment_hosts.txt); do
		ssh -n -f $i "bash -c 'source $GREENPLUM_PATH; cd $EXT_HOST_DATA_DIR/; ./stop_gpfdist.sh'"
	done
}
start_gpfdist()
{
	stop_gpfdist
	sleep 1
	if [ "$VERSION" == "gpdb_6" -o "$VERSION" == "gpdb_7" ]; then
		for i in $(psql -v ON_ERROR_STOP=1 -q -AXtc "select rank() over (partition by g.hostname order by g.datadir), g.hostname, g.datadir from gp_segment_configuration g where g.content >= 0 and g.role = 'p' order by g.hostname"); do
			CHILD=$(echo $i | awk -F '|' '{print $1}')
			EXT_HOST=$(echo $i | awk -F '|' '{print $2}')
			GEN_DATA_PATH=$(echo $i | awk -F '|' '{print $3}')
			GEN_DATA_PATH=$GEN_DATA_PATH/pivotalguru
			PORT=$(($GPFDIST_PORT + $CHILD))
			echo "executing on $EXT_HOST ./start_gpfdist.sh $PORT $GEN_DATA_PATH"
			ssh -n -f $EXT_HOST "bash -c 'source $GREENPLUM_PATH; cd $EXT_HOST_DATA_DIR/; ./start_gpfdist.sh $PORT $GEN_DATA_PATH'"
			sleep 1
		done
	else
		for i in $(psql -v ON_ERROR_STOP=1 -q -AXtc "select rank() over (partition by g.hostname order by p.fselocation), g.hostname, p.fselocation as path from gp_segment_configuration g join pg_filespace_entry p on g.dbid = p.fsedbid join pg_tablespace t on t.spcfsoid = p.fsefsoid where g.content >= 0 and g.role = 'p' and t.spcname = 'pg_default' order by g.hostname"); do
			CHILD=$(echo $i | awk -F '|' '{print $1}')
			EXT_HOST=$(echo $i | awk -F '|' '{print $2}')
			GEN_DATA_PATH=$(echo $i | awk -F '|' '{print $3}')
			GEN_DATA_PATH=$GEN_DATA_PATH/pivotalguru
			PORT=$(($GPFDIST_PORT + $CHILD))
			echo "executing on $EXT_HOST ./start_gpfdist.sh $PORT $GEN_DATA_PATH"
			ssh -n -f $EXT_HOST "bash -c 'source $GREENPLUM_PATH; cd $EXT_HOST_DATA_DIR/; ./start_gpfdist.sh $PORT $GEN_DATA_PATH'"
			sleep 1
		done
	fi
}

wait_mxgate_done()
{
	echo ""
	echo "Now load data by mxgate, this may take a while."
	echo -ne "Loading data "
	tuples=$(($start_count + 1))
	while [ "$tuples" -gt "$start_count" ]; do
		echo -ne "."
		sleep 5
		tuples=$(psql -v ON_ERROR_STOP=1 -AXtc "select count(*) from pg_stat_activity where application_name = 'matrixgate'")
	done

	echo ""
	echo "Done loading data"
	echo ""
}

if [[ "$VERSION" == *"gpdb"* ]]; then
  if [[ "$DATABASE_TYPE" == "matrixdb" && "$LOAD_DATA_TYPE" == "mxgate" ]]; then
	start_count=$(psql -v ON_ERROR_STOP=1 -AXtc "select count(*) from pg_stat_activity where application_name = 'matrixgate'")
  	do_mxgate_import
	wait_mxgate_done
  else
    copy_script
    start_gpfdist
    for i in $(ls $PWD/*.$filter.*.sql); do
      start_log

      id=$(echo $i | awk -F '.' '{print $1}')
      schema_name=$(echo $i | awk -F '.' '{print $2}')
      table_name=$(echo $i | awk -F '.' '{print $3}')

      echo "psql -v ON_ERROR_STOP=1 -f $i | grep INSERT | awk -F ' ' '{print \$3}'"
      tuples=$(psql -v ON_ERROR_STOP=1 -f $i | grep INSERT | awk -F ' ' '{print $3}'; exit ${PIPESTATUS[0]})

      log $tuples
	  stop_gpfdist
    done
  fi
	if [[ $ADD_FOREIGN_KEY == "true" ]]; then
	  	for i in $(ls $PWD/foreignkeys/*.$filter.*.sql); do
    		start_log

    		id=$(echo $i | awk -F '.' '{print $1}')
    		schema_name=$(echo $i | awk -F '.' '{print $2}')
    		table_name=$(echo $i | awk -F '.' '{print $3}')

    		echo "psql -v ON_ERROR_STOP=1 -f $i | grep INSERT | awk -F ' ' '{print \$3}'"
    		tuples=$(psql -v ON_ERROR_STOP=1 -f $i | grep INSERT | awk -F ' ' '{print $3}'; exit ${PIPESTATUS[0]})

    		log $tuples
    	done
  fi
else
	if [ "$PGDATA" == "" ]; then
		echo "ERROR: Unable to determine PGDATA environment variable.  Be sure to have this set for the admin user."
		exit 1
	fi

	PARALLEL=$(lscpu --parse=cpu | grep -v "#" | wc -l)
	echo "parallel: $PARALLEL"

	for i in $(ls $PWD/*.$filter.*.sql); do
		id=$(echo $i | awk -F '.' '{print $1}')
		schema_name=$(echo $i | awk -F '.' '{print $2}')
		table_name=$(echo $i | awk -F '.' '{print $3}')
		for p in $(seq 1 $PARALLEL); do
			filename=$(echo $PGDATA/pivotalguru_$p/$table_name.tbl*)
			if [[ -f $filename && -s $filename ]]; then
				start_log
				filename="'""$filename""'"
				echo "psql -v ON_ERROR_STOP=1 -f $i -v filename=\"$filename\" | grep COPY | awk -F ' ' '{print \$2}'"
				tuples=$(psql -v ON_ERROR_STOP=1 -f $i -v filename="$filename" | grep COPY | awk -F ' ' '{print $2}'; exit ${PIPESTATUS[0]})
				log $tuples
			fi
		done
	done
  if [[ ADD_FOREIGN_KEY == "true" ]]; then
    for i in $(ls $PWD/foreignkeys/*.$filter.*.sql); do
      id=$(echo $i | awk -F '.' '{print $1}')
      schema_name=$(echo $i | awk -F '.' '{print $2}')
      table_name=$(echo $i | awk -F '.' '{print $3}')
      for p in $(seq 1 $PARALLEL); do
        filename=$(echo $PGDATA/pivotalguru_$p/$table_name.tbl*)
        if [[ -f $filename && -s $filename ]]; then
          start_log
          filename="'""$filename""'"
          echo "psql -v ON_ERROR_STOP=1 -f $i -v filename=\"$filename\" | grep COPY | awk -F ' ' '{print \$2}'"
          tuples=$(psql -v ON_ERROR_STOP=1 -f $i -v filename="$filename" | grep COPY | awk -F ' ' '{print $2}'; exit ${PIPESTATUS[0]})
          log $tuples
        fi
      done
    done
  fi
fi

max_id=$(ls $PWD/*.sql | tail -1)
i=$(basename $max_id | awk -F '.' '{print $1}' | sed 's/^0*//')

if [[ "$VERSION" == *"gpdb"* ]]; then
	dbname="$PGDATABASE"
	if [ "$dbname" == "" ]; then
		dbname="$ADMIN_USER"
	fi

	if [ "$PGPORT" == "" ]; then
		export PGPORT=5432
	fi
fi


if [[ "$VERSION" == *"gpdb"* ]]; then
	schema_name="tpch"
	table_name="tpch"

	start_log
	#Analyze schema using analyzedb
	tables=(region nation customer supplier part partsupp orders lineitem)
	for t in "${tables[@]}"
	do
	echo "psql -v ON_ERROR_STOP=1 -q -AXtc \"analyze fullscan $schema_name.$t;\""
    psql -v ON_ERROR_STOP=1 -q -AXtc "analyze fullscan $schema_name.$t;"
	echo "psql -v ON_ERROR_STOP=1 -q -AXtc \"vacuum full ${schema_name}.${t};vacuum ${schema_name}.${t};\""
    psql -v ON_ERROR_STOP=1 -q -AXtc "vacuum full ${schema_name}.${t};"
	psql -v ON_ERROR_STOP=1 -q -AXtc "vacuum ${schema_name}.${t};"
  done
	tuples="0"
	log $tuples
else
	#postgresql analyze
	for t in $(psql -v ON_ERROR_STOP=1 -q -AXtc "select n.nspname, c.relname from pg_class c join pg_namespace n on n.oid = c.relnamespace and n.nspname = 'tpch' and c.relkind='r'"); do
		start_log
		schema_name=$(echo $t | awk -F '|' '{print $1}')
		table_name=$(echo $t | awk -F '|' '{print $2}')
		echo "psql -v ON_ERROR_STOP=1 -q -AXtc \"ANALYZE $schema_name.$table_name;\""
		psql -v ON_ERROR_STOP=1 -q -AXtc "ANALYZE $schema_name.$table_name;"
		tuples="0"
		log $tuples
		i=$((i+1))
	done
fi

end_step $step

echo "############################################################################"
echo ""