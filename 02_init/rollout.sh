#!/bin/bash
set -e

GEN_DATA_DIR=${12}

PWD=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source $PWD/../functions.sh
source_bashrc

step=init
init_log $step
start_log
schema_name="tpch"
table_name="init"

set_segment_bashrc()
{
	echo "if [ -f /etc/bashrc ]; then" > $PWD/segment_bashrc
	echo "	. /etc/bashrc" >> $PWD/segment_bashrc
	echo "fi" >> $PWD/segment_bashrc
	echo "export LD_PRELOAD=/lib64/libz.so.1 ps" >> $PWD/segment_bashrc
	chmod 755 $PWD/segment_bashrc
}
check_gucs()
{
	update_config="0"

	if [ "$VERSION" == "gpdb_5" ]; then
		counter=$(psql -v ON_ERROR_STOP=1 -q -t -A -c "show optimizer_join_arity_for_associativity_commutativity" | grep -i "18" | wc -l; exit ${PIPESTATUS[0]})
		if [ "$counter" -eq "0" ]; then
			echo "setting optimizer_join_arity_for_associativity_commutativity"
			gpconfig -c optimizer_join_arity_for_associativity_commutativity -v 18 --skipvalidation
			update_config="1"
		fi
	fi

	echo "check analyze_root_partition"
	counter=$(psql -v ON_ERROR_STOP=1 -q -t -A -c "show optimizer_analyze_root_partition" | grep -i "on" | wc -l; exit ${PIPESTATUS[0]})
	if [ "$counter" -eq "0" ]; then
		echo "enabling analyze_root_partition"
		gpconfig -c optimizer_analyze_root_partition -v on --masteronly
		update_config="1"
	fi

	echo "check gp_autostats_mode"
	counter=$(psql -v ON_ERROR_STOP=1 -q -t -A -c "show gp_autostats_mode" | grep -i "none" | wc -l; exit ${PIPESTATUS[0]})
	if [ "$counter" -eq "0" ]; then
		echo "changing gp_autostats_mode to none"
		gpconfig -c gp_autostats_mode -v none --masteronly
		update_config="1"
	fi

	echo "check default_statistics_target"
	counter=$(psql -v ON_ERROR_STOP=1 -q -t -A -c "show default_statistics_target" | grep "100" | wc -l; exit ${PIPESTATUS[0]})
	if [ "$counter" -eq "0" ]; then
		echo "changing default_statistics_target to 100"
		gpconfig -c default_statistics_target -v 100
		update_config="1"
	fi

	if [ "$update_config" -eq "1" ]; then
		echo "update cluster because of config changes"
		make_guc_effect
	fi
}
copy_config()
{
	echo "copy config files"
	if [ "$MASTER_DATA_DIRECTORY" != "" ]; then
		cp $MASTER_DATA_DIRECTORY/pg_hba.conf $GEN_DATA_DIR/log/
		cp $MASTER_DATA_DIRECTORY/postgresql.conf $GEN_DATA_DIR/log/
	fi
	#gp_segment_configuration
	psql -v ON_ERROR_STOP=1 -q -A -t -c "SELECT * FROM gp_segment_configuration" -o $GEN_DATA_DIR/log/gp_segment_configuration.txt
}
set_search_path()
{
	echo "psql -v ON_ERROR_STOP=1 -q -A -t -c \"ALTER USER $USER SET search_path=$schema_name,public;\""
	psql -v ON_ERROR_STOP=1 -q -A -t -c "ALTER USER $USER SET search_path=$schema_name,public;"
}

get_version
if [[ "$VERSION" == *"gpdb"* ]]; then
	set_segment_bashrc
#	check_gucs
	copy_config
fi
set_search_path

log

end_step $step
