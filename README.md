
## TPC-H benchmark scripts for YMatrix, Greenplum and PostgreSQL databases.

### Supported versions:
MatrixDB 4.*, 5.*

Greenplum 4.3, 5.*, 6.*, 7.*

Open Source Greenplum 5.*, 6.*, 7.*

Beta: PostgreSQL 10+

## Additional Prerequisite for MacOS users
```shell
brew install coreutils
```

## Execution
1. Export environment variables 
    ```
    export PGPORT=5432
    export PGDATA=/mxdata
    export PGDATABASE=tpch_s100
    ```
2. Generate configuration file `tpch_variables.sh`  
    ```
    ./tpch.sh -d matrixdb -s 100
    ```
    Args:
    ```
    -d [DATABASE_TYPE] 
        The database which TPC-H benchmark against, supported databases are matrixdb, greenplum, postgresql.
    -s [DATA_SCALE]
        The scale of the generated dataset in gigabytes, and specify this option to run benchmark against a desired dataset with specified scale, such as 1GB, 100GB, 1000GB.
    -h
        Show help messages.
    ```
3. You can review or edit `tpch_variables.sh` to make sure the variables are meet your requirements, please refer to `Options` section for more details.

    Execute `tpch.sh` according to the generated tpch_variables.sh
   ```
   ./tpch.sh
   ```

 
## Options
```shell

# The URL of our open source TPC-H repo, for potential upgrading. Automatically generated.
REPO_URL="https://github.com/ymatrix-data/TPC-H"

# The name of administrator user, if not set will automatically generate from 'whoami'
ADMIN_USER="mxadmin"

# The directory you install this TPC-H project, as reminded before. You must configure it manually.
INSTALL_DIR="/mxdata/TPC-H"

# Set to true in order to see exactly the query plan used
EXPLAIN_ANALYZE="false"

# Distributes data randomly across all segments using round-robin distribution if set to true
RANDOM_DISTRIBUTION="false"

# The concurrency num to run TPC-H in parallel
MULTI_USER_COUNT="1"

# The data scale which generate for TPC-H benchmark
mx="1"

# How many times to run TPC-H queries
SINGLE_USER_ITERATIONS="1"

# Compile TPC-H or not : true/false
RUN_COMPILE_TPCH="true"

# Generate data or not : true/false
RUN_GEN_DATA="false"

# Init TPC-H or not : true/false
RUN_INIT="true"

# Execute DDL or not : true/false
RUN_DDL="true"

# Load data into tables or not : true/false
RUN_LOAD="true"

# Run TPC-H standard queries or not : true/false
RUN_SQL="true"

# Generate final report for single user or not : true/false
RUN_SINGLE_USER_REPORT="true"

# Run TPC-H queries with parallel mode or not : true/false
RUN_MULTI_USER="true"

# Generate final report for multiple users or not : true/false
RUN_MULTI_USER_REPORT="true"

# The location of greenplum_path.sh, will generate automatically via /opt/ymatrix/matrixdb-5.0.0+enterprise if not set
GREENPLUM_PATH="//opt/ymatrix/matrixdb-5.0.0+enterprise/greenplum_path.sh"

# For region/nation, eg: USING mars2. Empty means heap
SMALL_STORAGE="USING mars2"

# For customer/part/partsupp/supplier, eg: with(appendonly=true, orientation=column), USING mars2. Empty means heap
MEDIUM_STORAGE="USING mars2"

# For lineitem, orders, eg: with(appendonly=true, orientation=column, compresstype=1z4), USING mars2. Empty means heap
LARGE_STORAGE="USING mars2"

# Enable ORCA or not : ON/OFF
OPTIMIZER="off"

# The directory of our generated log files. Configurable.
GEN_DATA_DIR="/mxdata/TPC-H/generated"

# Directory for some scripts and binary files transferred to the external host
EXT_HOST_DATA_DIR="~"

# Add foreign keys or not : true/false
ADD_FOREIGN_KEY="false"

# Warm up or not before actually run TPC-H standard queries: true/false
PREHEATING_DATA="true"

# Database type you want to run TPC-H benchmark, set empty means gpdb or postgresql
DATABASE_TYPE="matrixdb"
```

One more thing to remark: 
Every time new parameter(s) are generated, you will see a reminder
as following:
> There are new variables in the tpch_variables.sh file.  Please review to ensure the values are correct and then re-run this script.

which urges you to re-check them out of prudence, and run it again.

## Variables and Configuration
By default, the installation will create the scripts in the Master host. 
Variables can be changed by editing the dynamically configured tpch_variables.sh file
that is created the first time tpch.sh is run.  

Also by default, TPC-H files are generated on each Segment Host / Data Node in the 
Segement's PGDATA/pivotalguru directory.  If there isn't enough space in this directory
in each Segment, you can create a symbolic link to a drive location that does have 
enough space.

## Notes
- tpch_variables.sh file will be created with variables you can adjust
- Files for the benchmark will be created in a sub-directory named pivotalguru located 
in each segment directory on each segment host / data node.
You can update these directories to be symbolic links to better utilize the disk 
volumes you have available.
- Example of running tpch as root as a background process:
nohup ./tpch.sh > tpch.log 2>&1 < tpch.log &
