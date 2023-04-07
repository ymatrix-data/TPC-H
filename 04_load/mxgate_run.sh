#!/bin/bash
set -e

DATABASE=$1
MASTER_HOST=$2
MASTER_PORT=$3
GEN_DATA_PATH=$4
CORES=$5
MASTER_USER=$6
SEG_HOST=$7

pid=$(./mxgate_load.sh $DATABASE $MASTER_HOST $MASTER_PORT $GEN_DATA_PATH $CORES $MASTER_USER > $GEN_DATA_PATH/run_gate.log 2>&1 &)
sleep 5
res=$(grep -rn 'command not found' $GEN_DATA_PATH/run_gate.log)
if [[ $res != "" ]]; then
  echo $res
  exit 1
fi

if [ "$pid" -ne "0" ]; then
  sleep .1
  count=$(ps -ef 2> /dev/null | grep -v grep | awk -F ' ' '{print $2}' | grep $pid | wc -l)
  if [ "$count" -eq "0" ]; then
    echo "fail to start mxgate"
    exit 1
  fi
else
  echo "unable to start background process for mxgate"
  exit 1
fi

logs=$(ls $GEN_DATA_PATH | grep "mxgate.*.log")
for log in $logs
  do
    error=$(grep -rn "Failed" $GEN_DATA_PATH/$log | awk '{print $5}')
    if [ "$error" -ne "0" ]; then
      echo "found errors in mxgate log, for more details, please refer to $GEN_DATA_PATH/$log "
      exit 1
    fi
  done
