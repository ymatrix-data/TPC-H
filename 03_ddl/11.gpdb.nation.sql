CREATE TABLE tpch.nation
(N_NATIONKEY INTEGER, 
N_NAME CHAR(25), 
N_REGIONKEY INTEGER, 
N_COMMENT VARCHAR(152))
:SMALL_STORAGE
:DISTRIBUTED_BY;
:CREATE_MARS2_BTREE_INDEX;
