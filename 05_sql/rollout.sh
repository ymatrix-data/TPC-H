#!/bin/bash
set -e

echo "############################################################################"
echo "Run TPC-H queries for single user"
echo "############################################################################"
PWD=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source $PWD/../functions.sh
source_bashrc

RUN_SQL=${14}

if [ "$RUN_SQL" == "true" ]; then
  GEN_DATA_SCALE=$1
  EXPLAIN_ANALYZE=$2
  RANDOM_DISTRIBUTION=$3
  MULTI_USER_COUNT=$4
  SINGLE_USER_ITERATIONS=$5
  OPTIMIZER=${11}
  GEN_DATA_DIR=${12}
  CREATE_TBL=${10}
  RUN_ID=${17}
  SESSION_GUCS=${18}
  PREHEATING_DATA=${19}


  if [[ "$GEN_DATA_SCALE" == "" || "$EXPLAIN_ANALYZE" == "" || "$RANDOM_DISTRIBUTION" == "" || "$MULTI_USER_COUNT" == "" || "$SINGLE_USER_ITERATIONS" == "" ]]; then
    echo "You must provide the scale as a parameter in terms of Gigabytes, true/false to run queries with EXPLAIN ANALYZE option, true/false to use random distrbution, multi-user count, and the number of sql iterations."
    echo "Example: ./rollout.sh 100 false false 5 1"
    exit 1
  fi

  step=sql
  init_log $step

  rm -f $GEN_DATA_DIR/log/*single.explain_analyze.log
  create_tbl=""
  insert_tbl=""
  get_version
  mkdir -p $GEN_DATA_DIR/log/$RUN_ID
  for i in $(ls $PWD/*.tpch.*.sql); do
    for x in $(seq 1 $SINGLE_USER_ITERATIONS); do
      id=`echo $i | awk -F '.' '{print $3}'`
      schema_name=`echo $i | awk -F '.' '{print $2}'`
      table_name=`echo $i | awk -F '.' '{print $3}'`
      start_log
      if [ "$CREATE_TBL" = "true" ]; then
        create_tbl="CREATE TABLE tpch_tbl_"${id}" AS"
        insert_tbl="INSERT INTO tpch_tbl_"${id}
      fi
      if [ "$EXPLAIN_ANALYZE" == "false" ]; then
        echo "psql -v ON_ERROR_STOP=1 -A -q -t -P pager=off -v EXPLAIN_ANALYZE=\"\" -v CREATE_TABLE=\"${create_tbl}\" -v INSERT_TABLE=\"${insert_tbl}\"  -f $i | wc -l"
        if [[ "$VERSION" == *"gpdb"* ]];then
          tuples=$(PGOPTIONS="-c optimizer=$OPTIMIZER" psql -v ON_ERROR_STOP=1 -A -q -t -P pager=off -v EXPLAIN_ANALYZE="" -v CREATE_TABLE="$create_tbl" -v INSERT_TABLE="$insert_tbl" -c "${SESSION_GUCS}"  -f $i | wc -l; exit ${PIPESTATUS[0]})
        else 
          tuples=$(psql -v ON_ERROR_STOP=1 -q -AXtc -P pager=off -v EXPLAIN_ANALYZE="" -v CREATE_TABLE="$create_tbl" -v INSERT_TABLE="$insert_tbl" -f $i | wc -l; exit ${PIPESTATUS[0]})
        fi
      else
        myfilename=$(basename $i)
        mylogfile=$GEN_DATA_DIR/log/$RUN_ID/$myfilename.single.explain_analyze.log
        echo "gucs: ${SESSION_GUCS}" >> $mylogfile
        echo "psql -v ON_ERROR_STOP=1 -A -q -t -P pager=off -v EXPLAIN_ANALYZE=\"EXPLAIN ANALYZE\" -v CREATE_TABLE=\"${create_tbl}\" -v INSERT_TABLE=\"${insert_tbl}\" -f $i > $mylogfile"
        if [[ "$VERSION" == *"gpdb"* ]];then
          PGOPTIONS="-c optimizer=$OPTIMIZER" psql -v ON_ERROR_STOP=1 -A -q -t -P pager=off -v EXPLAIN_ANALYZE="EXPLAIN ANALYZE"  -v CREATE_TABLE="$create_tbl" -v INSERT_TABLE="$insert_tbl" -c "${SESSION_GUCS}"  -f $i >> $mylogfile
        else 
          psql -v ON_ERROR_STOP=1 -A -q -t -P pager=off -v EXPLAIN_ANALYZE="EXPLAIN ANALYZE"  -v CREATE_TABLE="$create_tbl" -v INSERT_TABLE="$insert_tbl" -f $i >> $mylogfile
        fi
        tuples="0"
      fi
      if [ "$PREHEATING_DATA" == "true" ] && [ "$x" == "1" ]; then
        continue
      fi
      log $tuples
    done
  done

  end_step $step
else
  echo "skipping RUN_SQL step ..."
fi

echo "############################################################################"
echo ""