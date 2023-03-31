#!/bin/bash
set -e

DATABASE=$1
MASTER_HOST=$2
MASTER_PORT=$3
GEN_DATA_PATH=$4
CORES=$5
MASTER_USER=$6

for f in `ls $GEN_DATA_PATH | grep tbl`
    do
      table_name=$(echo $f | awk -F '.' '{print $1}')
      mxgated \
      --source stdin \
      --format csv \
      --db-database $DATABASE \
      --db-master-host $MASTER_HOST \
      --db-master-port $MASTER_PORT \
      --db-user $MASTER_USER \
      --time-format raw \
      --delimiter "|" \
      --target tpch.$table_name \
      --stream-prepared 2 \
      --parallel $CORES < $GEN_DATA_PATH/$f > $GEN_DATA_PATH/mxgate.$f.log 2>&1 &

      pid=$!
      #echo "mxgate pid is $pid"
      if [ "$pid" -ne "0" ]; then
	      sleep 1
	      count=$(ps -ef 2> /dev/null | grep -v grep | awk -F ' ' '{print $2}' | grep $pid | wc -l)
	      if [ "$count" -eq "0" ]; then
          echo "fail to start mxgate"
		      exit 1
	      fi
      else
	      echo "unable to start background process for mxgate"
	      exit 1
      fi
    done

logs=$(ls $GEN_DATA_PATH | grep "mxgate.*.log")
for log in $logs
  do
    error=$(grep -rn "ERROR" $GEN_DATA_PATH/$log | wc -l)
    if [ "$error" -ne "0" ]; then
      echo "found errors in mxgate log, for more details, please refer to $GEN_DATA_PATH/$log "
      exit 1
    fi
  done
