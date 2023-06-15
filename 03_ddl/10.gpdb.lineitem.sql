CREATE TABLE tpch.lineitem
(L_ORDERKEY BIGINT,
L_PARTKEY INT,
L_SUPPKEY INT,
L_LINENUMBER INTEGER,
L_QUANTITY SMALLINT :MARS_ENCODING,
L_EXTENDEDPRICE float8,
L_DISCOUNT float8,
L_TAX float8,
L_RETURNFLAG "char" :MARS_ENCODING,
L_LINESTATUS "char" :MARS_ENCODING,
L_SHIPDATE DATE :MARS_ENCODING,
L_COMMITDATE DATE,
L_RECEIPTDATE DATE :MARS_ENCODING,
L_SHIPINSTRUCT TEXT :MARS_ENCODING,
L_SHIPMODE TEXT :MARS_ENCODING,
L_COMMENT TEXT)
:LARGE_STORAGE
:DISTRIBUTED_BY
PARTITION BY RANGE (L_SHIPDATE)
(start('1992-01-01') INCLUSIVE end ('1998-12-31') INCLUSIVE every (interval '1 year'),
default partition others);
:CREATE_MARS_BTREE_INDEX
