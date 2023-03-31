#!/bin/bash

set -e

echo "############################################################################"
PWD=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source $PWD/functions.sh
source_bashrc

GEN_DATA_SCALE="$1"
EXPLAIN_ANALYZE="$2"
RANDOM_DISTRIBUTION="$3"
MULTI_USER_COUNT="$4"
RUN_COMPILE_TPCH="$5"
RUN_GEN_DATA="$6"
RUN_INIT="$7"
RUN_DDL="$8"
RUN_LOAD="$9"
RUN_SQL="${10}"
RUN_SINGLE_USER_REPORT="${11}"
RUN_MULTI_USER="${12}"
RUN_MULTI_USER_REPORT="${13}"
SINGLE_USER_ITERATIONS="${14}"
SMALL_STORAGE="${16}"
MEDIUM_STORAGE="${17}"
LARGE_STORAGE="${18}"
CREATE_TBL="${19}"
OPTIMIZER="${20}"
GEN_DATA_DIR="${21}"
EXT_HOST_DATA_DIR="${22}"
ADD_FOREIGN_KEY="${23}"
TPCH_RUN_ID="${24}"
TPCH_SESSION_GUCS="${25}"
PREHEATING_DATA="${26}"
DATABASE_TYPE="${27}"
LOAD_DATA_TYPE="${28}"
PURE_SCRIPT_MODE="${29}"

if [[ "$GEN_DATA_SCALE" == "" || "$EXPLAIN_ANALYZE" == "" || "$RANDOM_DISTRIBUTION" == "" || "$MULTI_USER_COUNT" == "" || "$RUN_COMPILE_TPCH" == "" || "$RUN_GEN_DATA" == "" || "$RUN_INIT" == "" || "$RUN_DDL" == "" || "$RUN_LOAD" == "" || "$RUN_SQL" == "" || "$RUN_SINGLE_USER_REPORT" == "" || "$RUN_MULTI_USER" == "" || "$RUN_MULTI_USER_REPORT" == "" || "$SINGLE_USER_ITERATIONS" == "" ]]; then
	echo "Parameters: scale, explain T/F, random T/F, multi-user count, run compile T/F, run gen_data T/F, run init T/F, run DDL T/F, run load T/F, run SQL T/F, run single report T/F, run multi-user T/F, run multi report T/F, and single user iterations count."
	echo "Example: ./rollout.sh 100 false false 5 true true true true true true true true true 1"
	exit 1
fi

QUIET=$5

create_directories()
{
	if [ ! -d $GEN_DATA_DIR/log ]; then
		echo "Creating log directory"
		mkdir $GEN_DATA_DIR/log
	fi
}

create_directories

if [ "$RUN_COMPILE_TPCH" == "true" ]; then
	rm -f $GEN_DATA_DIR/log/end_compile_tpch.log
fi
if [ "$RUN_GEN_DATA" == "true" ]; then
	rm -f $GEN_DATA_DIR/log/end_gen_data.log
fi
if [ "$RUN_INIT" == "true" ]; then
	rm -f $GEN_DATA_DIR/log/end_init.log
fi
if [ "$RUN_DDL" == "true" ]; then
	rm -f $GEN_DATA_DIR/log/end_ddl.log
fi
if [ "$RUN_LOAD" == "true" ]; then
	rm -f $GEN_DATA_DIR/log/end_load.log
fi
if [ "$RUN_SQL" == "true" ]; then
	rm -f $GEN_DATA_DIR/log/end_sql.log
fi
if [ "$RUN_SINGLE_USER_REPORT" == "true" ]; then
	rm -f $GEN_DATA_DIR/log/end_single_user_reports.log
fi
if [ "$RUN_MULTI_USER" == "true" ]; then
	rm -f $GEN_DATA_DIR/log/end_testing_*.log
fi
if [ "$RUN_MULTI_USER_REPORT" == "true" ]; then
	rm -f $GEN_DATA_DIR/log/end_multi_user_reports.log
fi

echo "Exchange ssh keys"
get_version
if [[ "$VERSION" == *"gpdb"* || "$VERSION" == "*oss*" ]]; then
	echo "INFO: ssh keys are exchanged as part of database setup."
else
	echo "INFO: Make sure passwordless ssh is allowed."
	if [ ! -d ~/.ssh ]; then
		echo "mkdir ~/.ssh"
		mkdir ~/.ssh
	fi
	if [ ! -f ~/.ssh/id_rsa ]; then
		echo "ssh-keygen -t rsa -N \"\" -f ~/.ssh/id_rsa"
		ssh-keygen -t rsa -N "" -f ~/.ssh/id_rsa
		echo "cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys"
		cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
	fi
fi
echo "############################################################################"
echo ""

if [ "$DATABASE_TYPE" == "matrixdb" ]; then
		set_gucs
		if [ "$GEN_DATA_SCALE" -lt "1000" ]; then
			TPCH_SESSION_GUCS="set statement_mem to '1GB';"
		else
			TPCH_SESSION_GUCS="set statement_mem to '2GB';"
		fi
fi

for i in $(ls -d $PWD/0*); do
	echo "Run $i/rollout.sh"
	echo ""
	$i/rollout.sh $GEN_DATA_SCALE $EXPLAIN_ANALYZE $RANDOM_DISTRIBUTION $MULTI_USER_COUNT $SINGLE_USER_ITERATIONS $GREENPLUM_PATH "$SMALL_STORAGE" "$MEDIUM_STORAGE" "$LARGE_STORAGE" $CREATE_TBL $OPTIMIZER $GEN_DATA_DIR $EXT_HOST_DATA_DIR $RUN_SQL $RUN_SINGLE_USER_REPORT $ADD_FOREIGN_KEY $TPCH_RUN_ID "$TPCH_SESSION_GUCS" $PREHEATING_DATA $DATABASE_TYPE $LOAD_DATA_TYPE $PURE_SCRIPT_MODE
done
