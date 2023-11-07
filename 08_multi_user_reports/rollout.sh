#!/bin/bash
set -e

echo "############################################################################"
echo "Generate multi user report"
echo "############################################################################"

GEN_DATA_DIR=${12}

PWD=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source $PWD/../functions.sh
source_bashrc
step="multi_user_reports"

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

filename=$(ls $PWD/*.copy.*.sql)

for i in $(ls $GEN_DATA_DIR/log/rollout_testing_*); do
	logfile="'""$i""'"
	
        echo "psql -v ON_ERROR_STOP=1 -X -a -f $filename -v LOGFILE=\"$logfile\""
        psql -v ON_ERROR_STOP=1 -X -a -f $filename -v LOGFILE="$logfile"
done

psql -v ON_ERROR_STOP=1 -t -A -c -X "select 'analyze ' || n.nspname || '.' || c.relname || ';' from pg_class c join pg_namespace n on n.oid = c.relnamespace and n.nspname = 'tpch_testing'" | psql -v ON_ERROR_STOP=1 -t -A -e -X

psql -v ON_ERROR_STOP=1 -F $'\t' -A -P pager=off -f $PWD/detailed_report.sql
echo ""

end_step $step

echo "############################################################################"
echo ""