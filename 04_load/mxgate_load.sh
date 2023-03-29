#!/bin/bash
set -e

DATABASE=$1
MASTER_HOST=$2
MASTER_PORT=$3
GEN_DATA_PATH=$4

for f in `ls $GEN_DATA_PATH | grep tbl`
    do
      table_name=$(echo $f | awk -F '.' '{print $1}')
      mxgated \
      --source stdin \
      --format csv \
      --db-database $DATABASE \
      --db-master-host $MASTER_HOST \
      --db-master-port $MASTER_PORT \
      --db-user mxadmin \
      --time-format raw \
      --delimiter "|" \
      --target tpch.$table_name \
      --parallel 64 < $GEN_DATA_PATH/$f
    done