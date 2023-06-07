CREATE TABLE tpch.part
(P_PARTKEY INT,
P_NAME TEXT :MARS3_ENCODING,
P_MFGR TEXT,
P_BRAND TEXT :MARS3_ENCODING,
P_TYPE TEXT :MARS3_ENCODING,
P_SIZE SMALLINT :MARS3_ENCODING,
P_CONTAINER TEXT :MARS3_ENCODING,
P_RETAILPRICE float8,
P_COMMENT TEXT)
:MEDIUM_STORAGE
:DISTRIBUTED_BY
:CREATE_MARS3_BTREE_INDEX;
CREATE INDEX ON tpch.part USING mars3_brin(P_NAME, P_BRAND, P_TYPE, P_SIZE, P_CONTAINER);
