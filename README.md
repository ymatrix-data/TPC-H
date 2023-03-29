
## TPC-H benchmark scripts for Greenplum and PostgreSQL databases.

### Supported versions:
MatrixDB 2.*, 3.*, 4.*, 5.*

Greenplum 4.3, 5.*, 6.*, 7.*

Open Source Greenplum 5.*, 6.*, 7.*

Beta: PostgreSQL 10.*

## TPC-H Information
Based on version 2.17.1 of TPC-H.

## Additional Prerequisite for MacOS users
```shell
brew install coreutils
```

## Query Options


### **NOTICE**: 
```
please export PGPORT, PGDATA, PGDATABASE according to your demands before run TPC-H
```

You can have the queries execute with "EXPLAIN ANALYZE" in order to see exactly the 
query plan used, the cost, the memory used, etc.  This is done in tpch_variables.sh
like this:
EXPLAIN_ANALYZE="true"

Note:
0. The tpch_variables.sh file will be generated automatically for you after having
run the scripts for the first time. **Important** to note: you must properly 
configure the INSTALLER_DIR to continue the execution of scripts. It should be
the directory you install this TPC-H project. 

1. The EXPLAIN ANALYZE option is only available when using the standard TPC-H 
queries.
   
2. The following gives you a glimpse of the meaning of each parameter:
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
GEN_DATA_SCALE="1"

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

# Insert the selected data from current TPC-H tables into a new table : true/false
CREATE_TBL="false"

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

## Storage Options
Table storage is defined in tpch_variables.sh and is configured for optimal performance as default. 

### mars2 support
we support mars2 storage in new versions. 

#### Usage
Edit tpch_variables.sh:
```bash
SMALL_STORAGE="" # For region/nation, eg: USING mars2. Empty means heap
MEDIUM_STORAGE="USING mars2" # For customer/part/partsupp/supplier, eg: with(appendonly=true, orientation=column), USING mars2. Empty means heap
LARGE_STORAGE="USING mars2" # For lineitem, orders, eg: with(appendonly=true, orientation=column, compresstype=1z4), USING mars2. Empty means heap
CREATE_TBL="" #Default value is false, for normal queries, ignore it. For mix queries, such as 'insert into table_N select ...', set it to true
```
As comments above suggest, tables with different expected size can be set different storage type. By setting "USING mars2", corresponding tables will use mars2 storages and a mars2_btree index will be created for each table.

#### Advanced tuning for mars2_btree index
In order to let mars_btree indexes work best for TPC-H benchmark, user can edit 03_ddl/mars2_btree_index.txt to modify on with column the index will be created.
```bash
1|customer|MEDIUM_STORAGE|C_CUSTKEY|
2|lineitem|LARGE_STORAGE|L_ORDERKEY|
3|nation|SMALL_STORAGE|N_NATIONKEY|
4|orders|LARGE_STORAGE|O_ORDERKEY|
5|part|MEDIUM_STORAGE|P_PARTKEY|
6|partsupp|MEDIUM_STORAGE|PS_PARTKEY|
7|region|SMALL_STORAGE|R_REGIONKEY|
8|supplier|MEDIUM_STORAGE|S_SUPPKEY|
```
Please focus on the 4th column, which will be exactly as the parameter of "USING mars2_btree()" inside the brackets. Multiple keys are allowable, such as "KEY1,KEY2". 

More advanced users can even add some options for the index, such as unique mode (add "WITH(uniquemode=true)" in the 5th column), which might not be likely applied in TPC-H benchmark, though.

**Attention: Don't modify other columns**


## Prerequisites
1. Supported Database installed and running
2. Connectivity is possible to the MASTER_HOST

## Variables and Configuration
By default, the installation will create the scripts in the Master host. 
Variables can be changed by editing the dynamically configured tpch_variables.sh file
that is created the first time tpch.sh is run.  

Also by default, TPC-H files are generated on each Segment Host / Data Node in the 
Segement's PGDATA/pivotalguru directory.  If there isn't enough space in this directory
in each Segment, you can create a symbolic link to a drive location that does have 
enough space.



## Execution
1. Execute tpch.sh
./tpch.sh


## Notes
- tpch_variables.sh file will be created with variables you can adjust
- Files for the benchmark will be created in a sub-directory named pivotalguru located 
in each segment directory on each segment host / data node.
You can update these directories to be symbolic links to better utilize the disk 
volumes you have available.
- Example of running tpch as root as a background process:
nohup ./tpch.sh > tpch.log 2>&1 < tpch.log &


## TPC-H Minor Modifications
1. Query alternative 15 was used in favor of the original so it is easier to parse in
these scripts.  Performance is essentially the same for both versions.
2. Query 1 documentation doesn't match query provided by TPC.  Range is supposed to be
dynamically set between 60 and 120 days and substitution doesn't seem to be working
with qgen.  So, hard code 90 days until this can be fixed by TPC.

# Trouble Shooting
1. For the very first time you run the script on **MacOS**, you'll probably see the prompt:
```shell
readlink: illegal option -- f
usage: readlink [-n] [file ...]
usage: dirname path
```
Just configure the correct INSTALL_DIR mannually in tpch_variables.sh.

OR,

run:
```shell
brew install coreutils
```
to acquire the counterpart of the GNU tools on MacOS.

*Continuing...*
