#!/bin/bash

set -e
GEN_DATA_DIR=${4}
PWD=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source $PWD/../functions.sh

session_id=$1
EXPLAIN_ANALYZE=$2
OPTIMIZER=$3
CREATE_TBL=${5}
SESSION_GUCS=${18}
PREHEATING_DATA=${19}


if [[ "$session_id" == "" || "$EXPLAIN_ANALYZE" == "" ]]; then
	echo "Error: you must provide the session id and explain analyze true/false as parameters."
	echo "Example: ./rollout.sh 2 tpch false"
	echo "This will execute the TPC-H queries for sesion 2 that are dynamically without explain analyze."
	echo "created with qgen and not use EXPLAIN ANALYZE."
	exit 1
fi

source_bashrc

step=testing_$session_id

init_log $step

sql_dir=$PWD/tpch/$session_id

query_id=100

get_version

for order in $(seq 1 22); do
	query_id=$((query_id+1))
	query_number=$(grep begin $sql_dir/multi.sql | head -n"$order" | tail -n1 | awk -F ' ' '{print $2}' | awk -F 'q' '{print $2}')
	start_position=$(grep -n "begin q""$query_number" $sql_dir/multi.sql | awk -F ':' '{print $1}')
	end_position=$(grep -n "end q""$query_number" $sql_dir/multi.sql | awk -F ':' '{print $1}')
	target_filename="$query_id"".query.""$query_number"".sql"
	#add explain analyze 
	echo "echo \":EXPLAIN_ANALYZE\" > $sql_dir/$target_filename"
	echo ":EXPLAIN_ANALYZE" > $sql_dir/$target_filename
	echo ":CREATE_TABLE" >> $sql_dir/$target_filename
	echo "sed -n \"$start_position\",\"$end_position\"p $sql_dir/multi.sql >> $sql_dir/$target_filename"
	sed -n "$start_position","$end_position"p $sql_dir/multi.sql >> $sql_dir/$target_filename
	echo "sed -n \"$start_position\",\"$end_position\"p $sql_dir/multi.sql >> $sql_dir/$target_filename"
	echo ":INSERT_TABLE" >> $sql_dir/$target_filename
	sed -n "$start_position","$end_position"p $sql_dir/multi.sql >> $sql_dir/$target_filename
done
echo "rm -f $sql_dir/multi.sql"
rm -f $sql_dir/multi.sql 

tuples="0"
create_tbl=""
insert_tbl=""
for i in $(ls $sql_dir/*.sql); do

	start_log
	id=`echo $i | awk -F '.' '{print $3}'`
	schema_name=$session_id
	table_name=$(basename $i | awk -F '.' '{print $3}')

	if [ "$CREATE_TBL" == "true" ]; then
		create_tbl="CREATE TABLE tpch_tbl_"${id}"_"${session_id}" AS"
		insert_tbl="INSERT INTO tpch_tbl_"${id}"_"${session_id}
	fi

	if [ "$EXPLAIN_ANALYZE" == "false" ]; then
		echo "psql -v ON_ERROR_STOP=1 -A -q -t -P pager=off -v ON_ERROR_STOP=ON -v EXPLAIN_ANALYZE=\"\"  -v CREATE_TABLE=\"$create_tbl\" -v INSERT_TABLE=\"$insert_tbl\"  -f $i | wc -l"
		if [[ "$VERSION" == *"gpdb"* ]];then
			tuples=$(PGOPTIONS="-c optimizer=$OPTIMIZER -c enable_nestloop=off -c enable_mergejoin=off" psql -v ON_ERROR_STOP=1 -A -q -t -P pager=off -v ON_ERROR_STOP=ON -v EXPLAIN_ANALYZE="" -v CREATE_TABLE="$create_tbl" -v INSERT_TABLE="$insert_tbl" -c "${SESSION_GUCS}"  -f $i | wc -l; exit ${PIPESTATUS[0]})
		else 
			tuples=$(psql -v ON_ERROR_STOP=1 -q -AXtc -P pager=off -v ON_ERROR_STOP=ON -v EXPLAIN_ANALYZE="" -v CREATE_TABLE="$create_tbl" -v INSERT_TABLE="$insert_tbl" -f $i | wc -l; exit ${PIPESTATUS[0]})
		fi
		tuples=$(($tuples-1))
	else
		myfilename=$(basename $i)
		mylogfile=$GEN_DATA_DIR/log/"$session_id"".""$myfilename"".multi.explain_analyze.log"
		echo "psql -v ON_ERROR_STOP=1 -A -q -t -P pager=off -v ON_ERROR_STOP=ON -v EXPLAIN_ANALYZE=\"EXPLAIN (ANALYZE, VERBOSE, COSTS, BUFFERS, TIMING, SUMMARY, FORMAT JSON)\" -v CREATE_TABLE=\"$create_tbl\" -v INSERT_TABLE=\"$insert_tbl\" -f $i"
		if [[ "$VERSION" == *"gpdb"* ]];then
			PGOPTIONS="-c optimizer=$OPTIMIZER -c enable_nestloop=off -c enable_mergejoin=off" psql -v ON_ERROR_STOP=1 -A -q -t -P pager=off -v ON_ERROR_STOP=ON -v EXPLAIN_ANALYZE="EXPLAIN (ANALYZE, VERBOSE, COSTS, BUFFERS, TIMING, SUMMARY, FORMAT JSON)" -v CREATE_TABLE="$create_tbl" -v INSERT_TABLE="$insert_tbl" -c "${SESSION_GUCS}"  -f $i > $mylogfile
		else
			psql -v ON_ERROR_STOP=1 -A -q -t -P pager=off -v ON_ERROR_STOP=ON -v EXPLAIN_ANALYZE="EXPLAIN (ANALYZE, VERBOSE, COSTS, BUFFERS, TIMING, SUMMARY, FORMAT JSON)" -v CREATE_TABLE="$create_tbl" -v INSERT_TABLE="$insert_tbl" -f $i > $mylogfile 
		fi
		tuples="0"
	fi
		
	#remove the extra line that \timing adds
	log $tuples
done

end_step $step
