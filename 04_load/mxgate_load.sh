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
      mxgate \
      --source stdin \
      --format csv \
      --db-database $DATABASE \
      --db-master-host $MASTER_HOST \
      --db-master-port $MASTER_PORT \
      --db-user $MASTER_USER \
      --time-format raw \
      --delimiter "|" \
      --target tpch.$table_name \
      --stream-prepared 0 \
      --parallel $CORES < $GEN_DATA_PATH/$f > $GEN_DATA_PATH/mxgate.$table_name.log
    done
