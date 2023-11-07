#!/bin/bash
set -e

echo "############################################################################"
echo "Generate single user report"
echo "############################################################################"

GEN_DATA_DIR=${12}
RUN_SINGLE_USER_REPORT=${15}

if [ "$RUN_SINGLE_USER_REPORT" == "true" ]; then
  PWD=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
  source $PWD/../functions.sh
  source_bashrc
  step=single_user_reports

  init_log $step

  get_version
  if [[ "$VERSION" == *"gpdb"* ]]; then
    filter="gpdb"
  elif [ "$VERSION" == "postgresql" ]; then
    filter="postgresql"
  else
    echo "ERROR: Unsupported VERSION!"
    exit 1
  fi

  for i in $(ls $PWD/*.$filter.*.sql); do
    echo "psql -v ON_ERROR_STOP=1 -X -a -f $i"
    psql -v ON_ERROR_STOP=1 -X -a -f $i
    echo ""
  done

  for i in $(ls $PWD/*.copy.*.sql); do
    logstep=$(echo $i | awk -F 'copy.' '{print $2}' | awk -F '.' '{print $1}')
    logfile="$GEN_DATA_DIR/log/rollout_""$logstep"".log"
    logfile="'""$logfile""'"
    echo "psql -v ON_ERROR_STOP=1 -X -a -f $i -v LOGFILE=\"$logfile\""
    psql -v ON_ERROR_STOP=1 -X -a -f $i -v LOGFILE="$logfile"
    echo ""
  done

  psql -v ON_ERROR_STOP=1 -q -t -A -c -X "select 'analyze ' || n.nspname || '.' || c.relname || ';' from pg_class c join pg_namespace n on n.oid = c.relnamespace and n.nspname = 'tpch_reports'" | psql -v ON_ERROR_STOP=1 -t -A -e -X

  echo "********************************************************************************"
  echo "Generate Data"
  echo "********************************************************************************"
  psql -F $'\t' -A -v ON_ERROR_STOP=1 -P pager=off -f $PWD/gen_data_report.sql
  echo ""
  echo "********************************************************************************"
  echo "Data Loads"
  echo "********************************************************************************"
  psql -F $'\t' -A -v ON_ERROR_STOP=1 -P pager=off -f $PWD/loads_report.sql
  echo ""
  echo "********************************************************************************"
  echo "Analyze"
  echo "********************************************************************************"
  psql -F $'\t' -A -v ON_ERROR_STOP=1 -P pager=off -f $PWD/analyze_report.sql
  echo ""
  echo ""
  echo "********************************************************************************"
  echo "Queries"
  echo "********************************************************************************"
  psql -F $'\t' -A -v ON_ERROR_STOP=1 -P pager=off -f $PWD/queries_report.sql
  echo ""
  end_step $step
else
  echo "skipping RUN_SINGLE_USER_REPORT step ..."
fi

echo "############################################################################"
echo ""