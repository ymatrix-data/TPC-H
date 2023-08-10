CREATE TABLE tpch.SUPPLIER 
(S_SUPPKEY INT,
S_NAME TEXT,
S_ADDRESS TEXT,
S_NATIONKEY SMALLINT,
S_PHONE TEXT,
S_ACCTBAL float8,
S_COMMENT TEXT)
:MEDIUM_STORAGE
:DISTRIBUTED_BY
:CREATE_MARS_BTREE_INDEX;