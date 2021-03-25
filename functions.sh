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
	VERSION=$(psql -v ON_ERROR_STOP=1 -t -A -c "SELECT CASE WHEN POSITION ('Greenplum Database 4.3' IN version) > 0 THEN 'gpdb_4_3' WHEN POSITION ('Greenplum Database 5' IN version) > 0 THEN 'gpdb_5' WHEN POSITION ('Greenplum Database 6' IN version) > 0 THEN 'gpdb_6' WHEN POSITION ('Greenplum Database 7' IN version) > 0 THEN 'gpdb_7' ELSE 'postgresql' END FROM version();") 
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
		psql -v ON_ERROR_STOP=1 -t -A -c "SELECT DISTINCT hostname FROM gp_segment_configuration WHERE role = 'p' AND content >= 0" -o $LOCAL_PWD/segment_hosts.txt
	else
		#must be PostgreSQL
		echo $MASTER_HOST > $LOCAL_PWD/segment_hosts.txt
	fi
}

