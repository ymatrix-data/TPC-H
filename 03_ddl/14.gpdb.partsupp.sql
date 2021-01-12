CREATE TABLE tpch.partsupp
(PS_PARTKEY INT,
PS_SUPPKEY INT,
PS_AVAILQTY INTEGER,
PS_SUPPLYCOST DECIMAL(15,2),
PS_COMMENT VARCHAR(199))
:MEDIUM_STORAGE
:DISTRIBUTED_BY;
