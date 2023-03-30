#!/bin/bash
set -e

PWD=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

PURE_SCRIPT_MODE="$1"
VAR_PATH="$2"

MYCMD="tpch.sh"
MYVAR="tpch_variables.sh"
new_variable="0"

##################################################################################################################################################
# Functions
##################################################################################################################################################

check_variables()
{
	if [ "$GEN_DATA_SCALE" -lt "1000" ]; then
		storage="USING mars2 WITH (compress_threshold=12000)"
	else
		storage="USING mars2 WITH (compress_threshold=12000,compresstype=zstd,compresslevel=1)"
	fi
	### Make sure variables file is available
	if [ ! -f "$PWD/$MYVAR" ]; then
		touch $PWD/$MYVAR
		new_variable=$(($new_variable + 1))
	fi
	local count=$(grep "REPO_URL=" $MYVAR | wc -l)
	if [ "$count" -eq "0" ]; then
		echo "## NOTE: Please export PGPORT, PGDATA, PGDATABASE according to your demands before run TPC-H" >> $MYVAR
		echo "# The github repo url for ymatrix-data TPC-H" >> $MYVAR
		echo "REPO_URL=\"https://github.com/ymatrix-data/TPC-H\"" >> $MYVAR
		new_variable=$(($new_variable + 1))
	fi
	local count=$(grep "ADMIN_USER=" $MYVAR | wc -l)
	if [ "$count" -eq "0" ]; then
		ADMIN_USER=$(whoami)
		echo "# Current hostname, if not set will automatically get from 'whoami'" >> $MYVAR
		echo "ADMIN_USER=\"$ADMIN_USER\"" >> $MYVAR
		new_variable=$(($new_variable + 1))
	fi
	local count=$(grep "INSTALL_DIR=" $MYVAR | wc -l)
	if [ "$count" -eq "0" ]; then
	  if [[ "$OSTYPE" == "darwin"* ]]; then
		  INSTALL_DIR=$(dirname $(greadlink -f $0))
		else
		  INSTALL_DIR=$(dirname $(readlink -f $0))
		fi
		echo "# TPC-H install directory" >> $MYVAR
		echo "INSTALL_DIR=\"$INSTALL_DIR\"" >> $MYVAR
		new_variable=$(($new_variable + 1))
	fi
	local count=$(grep "EXPLAIN_ANALYZE=" $MYVAR | wc -l)
	if [ "$count" -eq "0" ]; then
		echo "# Set to true in order to see exactly the query plan used" >> $MYVAR
		echo "EXPLAIN_ANALYZE=\"false\"" >> $MYVAR
		new_variable=$(($new_variable + 1))
	fi
	local count=$(grep "RANDOM_DISTRIBUTION=" $MYVAR | wc -l)
	if [ "$count" -eq "0" ]; then
		echo "# Distributes data randomly across all segments using round-robin distribution if set to true" >> $MYVAR
		echo "RANDOM_DISTRIBUTION=\"false\"" >> $MYVAR
		new_variable=$(($new_variable + 1))
	fi
	local count=$(grep "MULTI_USER_COUNT" $MYVAR | wc -l)
	if [ "$count" -eq "0" ]; then
		echo "# The concurrency num to run TPC-H in parallel" >> $MYVAR
		echo "MULTI_USER_COUNT=\"1\"" >> $MYVAR
		new_variable=$(($new_variable + 1))
	fi
	local count=$(grep "GEN_DATA_SCALE" $MYVAR | wc -l)
	if [ "$count" -eq "0" ]; then
		echo "# The data scale which generate for TPC-H benchmark"  >> $MYVAR
		if [ -n "$GEN_DATA_SCALE" ]; then
    		echo "GEN_DATA_SCALE=\"$GEN_DATA_SCALE\"" >> $MYVAR
		else
			echo "GEN_DATA_SCALE=\"1\"" >> $MYVAR
		fi
		new_variable=$(($new_variable + 1))
	fi
	local count=$(grep "SINGLE_USER_ITERATIONS" $MYVAR | wc -l)
	if [ "$count" -eq "0" ]; then
		echo "# How many times to run TPC-H queries" >> $MYVAR
		echo "SINGLE_USER_ITERATIONS=\"1\"" >> $MYVAR
		new_variable=$(($new_variable + 1))
	fi
	#00
	local count=$(grep "RUN_COMPILE_TPCH" $MYVAR | wc -l)
	if [ "$count" -eq "0" ]; then
		echo "# Compile TPC-H or not : true/false" >> $MYVAR
		echo "RUN_COMPILE_TPCH=\"true\"" >> $MYVAR
		new_variable=$(($new_variable + 1))
	fi
	#01
	local count=$(grep "RUN_GEN_DATA" $MYVAR | wc -l)
	if [ "$count" -eq "0" ]; then
		echo "# Generate data or not : true/false" >> $MYVAR
		echo "RUN_GEN_DATA=\"true\"" >> $MYVAR
		new_variable=$(($new_variable + 1))
	fi
	#02
	local count=$(grep "RUN_INIT" $MYVAR | wc -l)
	if [ "$count" -eq "0" ]; then
		echo "# Init TPC-H or not : true/false" >> $MYVAR
		echo "RUN_INIT=\"true\"" >> $MYVAR
		new_variable=$(($new_variable + 1))
	fi
	#03
	local count=$(grep "RUN_DDL" $MYVAR | wc -l)
	if [ "$count" -eq "0" ]; then
		echo "# Execute DDL or not : true/false" >> $MYVAR
		echo "RUN_DDL=\"true\"" >> $MYVAR
		new_variable=$(($new_variable + 1))
	fi
	#04
	local count=$(grep "RUN_LOAD" $MYVAR | wc -l)
	if [ "$count" -eq "0" ]; then
		echo "# Load data into tables or not : true/false" >> $MYVAR
		echo "RUN_LOAD=\"true\"" >> $MYVAR
		new_variable=$(($new_variable + 1))
	fi
	#05
	local count=$(grep "RUN_SQL" $MYVAR | wc -l)
	if [ "$count" -eq "0" ]; then
		echo "# Run TPC-H standard queries or not : true/false" >> $MYVAR
		echo "RUN_SQL=\"true\"" >> $MYVAR
		new_variable=$(($new_variable + 1))
	fi
	#06
	local count=$(grep "RUN_SINGLE_USER_REPORT" $MYVAR | wc -l)
	if [ "$count" -eq "0" ]; then
		echo "# Generate final report for single user or not : true/false" >> $MYVAR
		echo "RUN_SINGLE_USER_REPORT=\"true\"" >> $MYVAR
		new_variable=$(($new_variable + 1))
	fi
	#07
	local count=$(grep "RUN_MULTI_USER" $MYVAR | wc -l)
	if [ "$count" -eq "0" ]; then
		echo "# Run TPC-H queries with parallel mode or not : true/false" >> $MYVAR
		echo "RUN_MULTI_USER=\"true\"" >> $MYVAR
		new_variable=$(($new_variable + 1))
	fi
	#08
	local count=$(grep "RUN_MULTI_USER_REPORT" $MYVAR | wc -l)
	if [ "$count" -eq "0" ]; then
		echo "# Generate final report for multiple users or not : true/false" >> $MYVAR
		echo "RUN_MULTI_USER_REPORT=\"true\"" >> $MYVAR
		new_variable=$(($new_variable + 1))
	fi
	#09
	local count=$(grep "GREENPLUM_PATH" $MYVAR | wc -l)
	if [ "$count" -eq "0" ]; then
		echo "# The location of greenplum_path.sh, will generate automatically via $GPHOME if not set" >> $MYVAR
		echo "GREENPLUM_PATH=\"/$GPHOME/greenplum_path.sh\"" >> $MYVAR
		new_variable=$(($new_variable + 1))
	fi
	#10
	local count=$(grep "SMALL_STORAGE" $MYVAR | wc -l)
	if [ "$count" -eq "0" ]; then
		echo "# For region/nation, eg: USING mars2. Empty means heap" >> $MYVAR
		if [[ "${DATABASE_TYPE}" == "matrixdb" ]]; then
			echo "SMALL_STORAGE=\"$storage\"" >> $MYVAR
		elif [[ "${DATABASE_TYPE}" == "greenplum"  ]]; then
			echo "SMALL_STORAGE=\"with(appendonly=true, orientation=column)\"" >> $MYVAR
		else
			echo "SMALL_STORAGE=\"\"" >> $MYVAR
		fi
		new_variable=$(($new_variable + 1))
	fi
	#11
	local count=$(grep "MEDIUM_STORAGE" $MYVAR | wc -l)
	if [ "$count" -eq "0" ]; then
		echo "# For customer/part/partsupp/supplier, eg: with(appendonly=true, orientation=column), USING mars2. Empty means heap" >> $MYVAR
		if [[ "${DATABASE_TYPE}" == "matrixdb" ]]; then
			echo "MEDIUM_STORAGE=\"$storage\"" >> $MYVAR
		elif [[ "${DATABASE_TYPE}" == "greenplum"  ]]; then
			echo "MEDIUM_STORAGE=\"with(appendonly=true, orientation=column)\"" >> $MYVAR
		else
			echo "MEDIUM_STORAGE=\"\"" >> $MYVAR
		fi
		new_variable=$(($new_variable + 1))
	fi
	#12
	local count=$(grep "LARGE_STORAGE" $MYVAR | wc -l)
	if [ "$count" -eq "0" ]; then
		echo "# For lineitem, orders, eg: with(appendonly=true, orientation=column, compresstype=1z4), USING mars2. Empty means heap" >> $MYVAR
		if [[ "${DATABASE_TYPE}" == "matrixdb" ]]; then
			echo "LARGE_STORAGE=\"$storage\"" >> $MYVAR
		elif [[ "${DATABASE_TYPE}" == "greenplum"  ]]; then
			echo "LARGE_STORAGE=\"with(appendonly=true, orientation=column)\"" >> $MYVAR
		else
			echo "LARGE_STORAGE=\"\"" >> $MYVAR
		fi
		new_variable=$(($new_variable + 1))
	fi
	#13
	local count=$(grep "OPTIMIZER" $MYVAR | wc -l)
	if [ "$count" -eq "0" ]; then
		echo "# Enable ORCA or not : ON/OFF" >> $MYVAR
		echo "OPTIMIZER=\"off\"" >> $MYVAR
		new_variable=$(($new_variable + 1))
	fi
	#14
	local count=$(grep "GEN_DATA_DIR" $MYVAR | wc -l)
	if [ "$count" -eq "0" ]; then
		echo "# Directory for generated data" >> $MYVAR
		echo "GEN_DATA_DIR=\"$PWD/generated\"" >> $MYVAR
		new_variable=$(($new_variable + 1))
	fi
	#15
	local count=$(grep "EXT_HOST_DATA_DIR" $MYVAR | wc -l)
	if [ "$count" -eq "0" ]; then
		echo "# Directory for some scripts and binary files transferred to the external host" >> $MYVAR
		echo "EXT_HOST_DATA_DIR=\"~\"" >> $MYVAR
		new_variable=$(($new_variable + 1))
	fi
	#16
	local count=$(grep "ADD_FOREIGN_KEY" $MYVAR | wc -l)
	if [ "$count" -eq "0" ]; then
		echo "# Add foreign keys or not : true/false" >> $MYVAR
		echo "ADD_FOREIGN_KEY=\"false\"" >> $MYVAR
		new_variable=$(($new_variable + 1))
	fi
	#17
	local count=$(grep "CREATE_TBL=" $MYVAR | wc -l)
	if [ "$count" -eq "0" ]; then
		echo "# Insert the selected data from current TPC-H tables into a new table : true/false" >> $MYVAR
		echo "CREATE_TBL=\"false\"" >> $MYVAR
		new_variable=$(($new_variable + 1))
	fi
	#18
  	local count=$(grep "PREHEATING_DATA=" $MYVAR | wc -l)
  	if [ "$count" -eq "0" ]; then
    	echo "# Warm up or not before actually run TPC-H standard queries: true/false" >> $MYVAR
    	echo "PREHEATING_DATA=\"true\"" >> $MYVAR
    	new_variable=$(($new_variable + 1))
 	fi
  	#19
  	local count=$(grep "DATABASE_TYPE=" $MYVAR | wc -l)
  	if [ "$count" -eq "0" ]; then
    	echo "# Database type you want to run TPC-H benchmark, set empty means gpdb or postgresql" >> $MYVAR
		if [ -n "$DATABASE_TYPE" ]; then
    		echo "DATABASE_TYPE=\"$DATABASE_TYPE\"" >> $MYVAR
		else
			echo "DATABASE_TYPE=\"matrixdb\"" >> $MYVAR
		fi
    	new_variable=$(($new_variable + 1))
  	fi
}

request_user_check_variables()
{
	if [ "$new_variable" -gt "0" ]; then
		echo "There are new variables in the tpch_variables.sh file.  Please review to ensure the values are correct and then re-run this script."
		exit 1
	fi
}

source_variables()
{
	echo "############################################################################"
	echo "Sourcing $MYVAR"
	echo "############################################################################"
	echo ""
	source $MYVAR
	if [ "$VAR_PATH" != "" ]; then
		echo "############################################################################"
		echo "Sourcing $VAR_PATH"
		echo "############################################################################"
		echo ""
		source $VAR_PATH
	fi
}

check_user()
{
	### Make sure root is executing the script. ###
	echo "############################################################################"
	echo "Make sure root is executing this script."
	echo "############################################################################"
	echo ""
	local WHOAMI=`whoami`
	if [ "$WHOAMI" != "root" ]; then
		echo "Script must be executed as root!"
		exit 1
	fi
}

yum_installs()
{
	### Install and Update Demos ###
	echo "############################################################################"
	echo "Install git and gcc with yum."
	echo "############################################################################"
	echo ""
	# Install git and gcc if not found
	local YUM_INSTALLED=$(yum --help 2> /dev/null | wc -l)
	local GCC_INSTALLED=$(gcc --help 2> /dev/null | wc -l)
	local GIT_INSTALLED=$(git --help 2> /dev/null | wc -l)

	if [ "$YUM_INSTALLED" -gt "0" ]; then
		if [ "$GCC_INSTALLED" -eq "0" ]; then
			yum -y install gcc
		fi
		if [ "$GIT_INSTALLED" -eq "0" ]; then
			yum -y install git
		fi
	else
		if [ "$GCC_INSTALLED" -eq "0" ]; then
			echo "gcc not installed and yum not found to install it."
			echo "Please install gcc and try again."
			exit 1
		fi
		if [ "$GIT_INSTALLED" -eq "0" ]; then
			echo "git not installed and yum not found to install it."
			echo "Please install git and try again."
			exit 1
		fi
	fi
	echo ""
}

repo_init()
{
	### Install repo ###
	echo "############################################################################"
	echo "Install the github repository."
	echo "############################################################################"
	echo ""

	internet_down="0"
	for j in $(curl google.com 2>&1 | grep "Couldn't resolve host"); do
		internet_down="1"
	done

	if [ ! -d $INSTALL_DIR ]; then
		if [ "$internet_down" -eq "1" ]; then
			echo "Unable to continue because repo hasn't been downloaded and Internet is not available."
			exit 1
		else
			echo ""
			echo "Creating install dir"
			echo "-------------------------------------------------------------------------"
			mkdir $INSTALL_DIR
			chown $ADMIN_USER $INSTALL_DIR
		fi
	fi

	if [ ! -d $INSTALL_DIR/$REPO ]; then
		if [ "$internet_down" -eq "1" ]; then
			echo "Unable to continue because repo hasn't been downloaded and Internet is not available."
			exit 1
		else
			echo ""
			echo "Creating $REPO directory"
			echo "-------------------------------------------------------------------------"
			mkdir $INSTALL_DIR/$REPO
			chown $ADMIN_USER $INSTALL_DIR/$REPO
			su -c "cd $INSTALL_DIR; GIT_SSL_NO_VERIFY=true; git clone --depth=1 $REPO_URL" $ADMIN_USER
		fi
	else
		chown -R $ADMIN_USER $INSTALL_DIR/$REPO
		if [ "$internet_down" -eq "0" ]; then
			git config --global user.email "$ADMIN_USER@$HOSTNAME"
			git config --global user.name "$ADMIN_USER"
			su -c "cd $INSTALL_DIR/$REPO; GIT_SSL_NO_VERIFY=true; git fetch --all; git reset --hard origin/master" $ADMIN_USER
		fi
	fi
}

script_check()
{
	### Make sure the repo doesn't have a newer version of this script. ###
	echo "############################################################################"
	echo "Make sure this script is up to date."
	echo "############################################################################"
	echo ""
	# Must be executed after the repo has been pulled
	local d=`diff $PWD/$MYCMD $INSTALL_DIR/$REPO/$MYCMD | wc -l`

	if [ "$d" -eq "0" ]; then
		echo "$MYCMD script is up to date so continuing to TPC-H."
		echo ""
	else
		echo "$MYCMD script is NOT up to date."
		echo ""
		cp $INSTALL_DIR/$REPO/$MYCMD $PWD/$MYCMD
		echo "After this script completes, restart the $MYCMD with this command:"
		echo "./$MYCMD"
		exit 1
	fi

}

echo_variables()
{
	echo "############################################################################"
	echo "REPO: $REPO"
	echo "REPO_URL: $REPO_URL"
	echo "ADMIN_USER: $ADMIN_USER"
	echo "INSTALL_DIR: $INSTALL_DIR"
	echo "MULTI_USER_COUNT: $MULTI_USER_COUNT"
	echo "GEN_DATA_SCALE: $GEN_DATA_SCALE"
	echo "SMALL_STORAGE: $SMALL_STORAGE"
	echo "MEDIUM_STORAGE: $MEDIUM_STORAGE"
	echo "LARGE_STORAGE: $LARGE_STORAGE"
	echo "PREHEATING_DATA: $PREHEATING_DATA"
	echo "DATABASE_TYPE: $DATABASE_TYPE"
	echo "############################################################################"
	echo ""
}

check_dir(){
  if [ ! -d $GEN_DATA_DIR ] ; then
		mkdir $GEN_DATA_DIR
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

set_gucs(){
	# Get the number of CPU cores
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

    # Query the number of segments in the database
    segnum=$(psql -v ON_ERROR_STOP=1 -t -A -c "select count(*) from gp_segment_configuration WHERE role = 'p' AND content >= 0;")

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
  	gpstop -u
}

function show_help()
{
    cat << EOF
TPC-H benchmark scripts for YMatrix, Greenplum and PostgreSQL databases.

Args:
   -h
      Show help messages.

   -d [database_type]

      Required, the database which TPC-H benchmark against, supported databases are matrixdb, greenplum, postgresql.

   -s [scale] 
      Required, scale of the generated dataset in gigabytes, and specify this option to run benchmark against a desired dataset with specified scale.

Usage:
    
    Run TPC-H against matrixdb with scale 100
	
    1. generate configuration file tpch_variables.sh
        "./tpch.sh -d matrixdb -s 100"
		
    2. run tpch benchmark based on configuration file tpch_variables.sh
        "./tpch.sh"
	
EOF
}

function parse_args()
{
    OPTIND=1
    while getopts ":d:s:h" opt; do
    case "$opt" in
        s) GEN_DATA_SCALE="$OPTARG";;
        d) DATABASE_TYPE="$OPTARG";;
        h) 
        show_help
        exit 0
        ;;
        \?)
        printf "%s\n" "Invalid Option! -$OPTARG" >&2
        exit 1
        ;;
        :)
        printf "%s\n" "-$OPTARG requires an argument" >&2
        exit 1
        ;;
    esac
    done
    shift "$((OPTIND - 1))"

	# Check if database_type is valid
	DATABASE_TYPE=$(echo $DATABASE_TYPE | tr [A-Z] [a-z]) 
    if [[ "${DATABASE_TYPE}" != "matrixdb" && "${DATABASE_TYPE}" != "greenplum" && "${DATABASE_TYPE}" != "postgresql" ]]; then
		printf "%s\n" "Invalid database: \"$DATABASE_TYPE\", supported databases are matrixdb, greenplum, postgresql." >&2
		printf "Execute \"./tpch -h\" to show help messages.\n"
		exit 1
    fi
}


##################################################################################################################################################
# Body
##################################################################################################################################################

if [ ! -f "$PWD/$MYVAR" ]; then
	parse_args $@
	printf "%s\n" "Generate tpch_variables.sh for \"$DATABASE_TYPE\"." >&2
	check_variables
	printf "Generate tpch_variables.sh successfully. \n"
	printf "%s\n" "Please review "$PWD/$MYVAR" to make sure the variables are meet your requirements."
	printf "Then execute \"./tpch.sh\" to run TPC-H benchmark. \n"
	exit 0
fi

export GREENPLUM_PATH=$GREENPLUM_PATH
if [ "$PURE_SCRIPT_MODE·" == "" ];then
	#check_user
	check_variables
	request_user_check_variables
	source_variables
	check_dir
	yum_installs
	#repo_init
	script_check
	echo_variables
else
	check_variables
	source_variables
	check_dir
	echo_variables
fi
if [ "$PREHEATING_DATA" == "true" ]; then
    SINGLE_USER_ITERATIONS=`expr $SINGLE_USER_ITERATIONS + 1`
fi
if [ "$TPCH_RUN_ID" == "" ]; then
    TPCH_RUN_ID=$(date "+%Y-%m-%d-%H-%M-%S")
fi

if [ "$DATABASE_TYPE" == "matrixdb" ]; then
  set_gucs
  if [ "$GEN_DATA_SCALE" -lt "1000" ]; then
      TPCH_SESSION_GUCS="set statement_mem to '1GB';"
  else
      TPCH_SESSION_GUCS="set statement_mem to '2GB';"
  fi
fi

cd $INSTALL_DIR; ./rollout.sh $GEN_DATA_SCALE $EXPLAIN_ANALYZE $RANDOM_DISTRIBUTION $MULTI_USER_COUNT $RUN_COMPILE_TPCH $RUN_GEN_DATA $RUN_INIT $RUN_DDL $RUN_LOAD $RUN_SQL $RUN_SINGLE_USER_REPORT $RUN_MULTI_USER $RUN_MULTI_USER_REPORT $SINGLE_USER_ITERATIONS $GREENPLUM_PATH "$SMALL_STORAGE" "$MEDIUM_STORAGE" "$LARGE_STORAGE" $CREATE_TBL $OPTIMIZER $GEN_DATA_DIR $EXT_HOST_DATA_DIR $ADD_FOREIGN_KEY $TPCH_RUN_ID "$TPCH_SESSION_GUCS" $PREHEATING_DATA $DATABASE_TYPE $PURE_SCRIPT_MODE

