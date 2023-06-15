CREATE TABLE tpch.customer
(C_CUSTKEY INT, 
C_NAME TEXT,
C_ADDRESS TEXT,
C_NATIONKEY SMALLINT,
C_PHONE TEXT,
C_ACCTBAL float8 :MARS_ENCODING,
C_MKTSEGMENT TEXT :MARS_ENCODING,
C_COMMENT TEXT)
:MEDIUM_STORAGE
:DISTRIBUTED_BY
:CREATE_MARS_BTREE_INDEX;
CREATE INDEX ON tpch.customer USING mars3_brin(C_ACCTBAL, C_MKTSEGMENT);
