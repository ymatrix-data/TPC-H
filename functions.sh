#!/bin/bash
set -e

count=$(alias | grep -w grep | wc -l)
if [ "$count" -gt "0" ]; then
        unalias grep
fi
count=$(alias | grep -w ls | wc -l)
if [ "$count" -gt "0" ]; then
        unalias ls
fi

export LD_PRELOAD=/lib64/libz.so.1 ps

LOCAL_PWD=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
OSVERSION=$(uname)
ADMIN_USER=$(whoami)
ADMIN_HOME=$(eval echo ~$ADMIN_USER)
GPFDIST_PORT=5000
MASTER_HOST=$(hostname | awk -F '.' '{print $1}')

get_version()
{
	#need to call source_bashrc first
	VERSION=$(psql -v ON_ERROR_STOP=1 -AXtc "SELECT CASE WHEN POSITION ('Greenplum Database 4.3' IN version) > 0 THEN 'gpdb_4_3' WHEN POSITION ('Greenplum Database 5' IN version) > 0 THEN 'gpdb_5' WHEN POSITION ('Greenplum Database 6' IN version) > 0 THEN 'gpdb_6' WHEN POSITION ('Greenplum Database 7' IN version) > 0 THEN 'gpdb_7' ELSE 'postgresql' END FROM version();") 
}
source_bashrc()
{
	startup_file=".bashrc"
	if [ ! -f ~/.bashrc ]; then
		if [ -f ~/.bash_profile ]; then
			startup_file=".bash_profile"
		else
			echo "touch ~/.bashrc"
			touch ~/.bashrc
		fi
	fi
	if [ "$GREENPLUM_PATH" == "" ]; then
		get_version
		if [[ "$VERSION" == *"gpdb"* ]]; then
			echo "$startup_file does not contain greenplum_path.sh"
			echo "Please update your $startup_file for $ADMIN_USER and try again."
			exit 1
		fi
	fi
	echo "source ~/$startup_file"
	# don't fail if an error is happening in the admin's profile
	source ~/$startup_file || true
	echo ""
}
check_log_path()
{
  echo "[DEBUG]: $GEN_DATA_DIR"
  if [[ "$GEN_DATA_DIR" == "" ]]; then
    echo "GEN_DATA_DIR log not set"
    exit 1
  fi
}
init_log()
{
#  check_log_path
	if [ -f $GEN_DATA_DIR/log/end_$1.log ]; then
		exit 0
	fi

	logfile=rollout_$1.log
	rm -f $GEN_DATA_DIR/log/$logfile
}
start_log()
{
#  check_log_path
	if [ "$OSVERSION" == "Linux" ]; then
		T="$(date +%s%N)"
	else
		T="$(gdate +%s%N)"
	fi
}
log()
{
#  check_log_path
	#duration
	if [ "$OSVERSION" == "Linux" ]; then
		T="$(($(date +%s%N)-T))"
	else
		#must be OSX which doesn't have nano-seconds
		T="$(($(gdate +%s%N)-T))"
	fi
	# seconds
	S="$((T/1000000000))"
	# milliseconds
	M="$((T/1000000))"

	#this is done for steps that don't have id values
	if [ "$id" == "" ]; then
		id="1"
	else
		id=$(basename $i | awk -F '.' '{print $1}')
	fi

	tuples=$1
	if [ "$tuples" == "" ]; then
		tuples="0"
	fi

	printf "$id|$schema_name.$table_name|$tuples|%02d:%02d:%02d.%03d\n" "$((S/3600%24))" "$((S/60%60))" "$((S%60))" "${M}" >> $GEN_DATA_DIR/log/$logfile
}
end_step()
{
#  check_log_path
	local logfile=end_$1.log
	touch $GEN_DATA_DIR/log/$logfile
}
create_hosts_file()
{
	get_version

	if [[ "$VERSION" == *"gpdb"* ]]; then
		psql -v ON_ERROR_STOP=1 -t -A -X -c "SELECT DISTINCT hostname FROM gp_segment_configuration WHERE role = 'p' AND content >= 0" -o $LOCAL_PWD/segment_hosts.txt
	else
		#must be PostgreSQL
		echo $MASTER_HOST > $LOCAL_PWD/segment_hosts.txt
	fi
}

get_cpu_cores_num()
{
  cores=$(nproc)
  cpu_cgroup_path=/sys/fs/cgroup/cpu
  if [ -f ${cpu_cgroup_path}/cpu.cfs_quota_us ]  && [ -f ${cpu_cgroup_path}/cpu.cfs_period_us ] ; then
    cfs_quota_us=$(cat ${cpu_cgroup_path}/cpu.cfs_quota_us)
    cfs_period_us=$(cat ${cpu_cgroup_path}/cpu.cfs_period_us)
    # judge whether inside a docker container, cpu cores is differ from physical machine
    if [ $cfs_quota_us -ne -1 ] && [ $cfs_period_us -ne 0 ]; then
       cores=`expr $cfs_quota_us / $cfs_period_us`
    fi
  fi
  echo $cores
}

make_guc_effect() {
	mx_provider=$(psql -v ON_ERROR_STOP=1 -AXtc "show mx_ha_provider;")
	if [[ "${mx_provider}" == "external" ]]; then
		mxstop -u
	else
		gpstop -u
	fi
}

function round_up() {
    bc << EOF
    num = $1;
    base = num / 1;
    if (((num - base) * 10) > 1 )
        base += 1;
    print base;
EOF
}

function set_gucs(){
	echo "############################################################################"
	echo "Set specific gucs"
	echo "############################################################################"
	# Get the number of CPU cores
	cores=$(get_cpu_cores_num)
	
	# Query the number of segments in the database
	segnum=$(psql -v ON_ERROR_STOP=1 -AXtc "select count(*) from gp_segment_configuration WHERE role = 'p' AND content >= 0;")

	# Calculate the number of parallel workers to use
	parallel_workers_float=$(echo "scale=2; $cores/2.0/$segnum" | bc)
	parallel_workers=$(round_up $parallel_workers_float)

  	gpconfig -c gp_interconnect_type -v tcp
  	gpconfig -c enable_indexscan -v off
  	gpconfig -c enable_mergejoin -v off
  	gpconfig -c enable_nestloop -v off
  	gpconfig -c enable_parallel_hash -v off
  	gpconfig -c gp_enable_hashjoin_size_heuristic -v on --skipvalidation
  	gpconfig -c gp_cached_segworkers_threshold -v 50
  	gpconfig -c max_parallel_workers_per_gather -v $parallel_workers
	
  	make_guc_effect
	echo "############################################################################"
	echo ""
}
