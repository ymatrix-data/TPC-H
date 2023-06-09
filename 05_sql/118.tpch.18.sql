:EXPLAIN_ANALYZE
:CREATE_TABLE
:INSERT_TABLE
-- using 1686115892 as a seed to the RNG


select
	c_name,
	c_custkey,
	o_orderkey,
	o_orderdate,
	round(o_totalprice) as totalprice,
	sum(l_quantity) as quantity
from
	customer,
	orders,
	lineitem
where
	o_orderkey in (
		select
			l_orderkey
		from
			lineitem
		group by
			l_orderkey having
				sum(l_quantity) > 315
	)
	and c_custkey = o_custkey
	and o_orderkey = l_orderkey
group by
	c_name,
	c_custkey,
	o_orderkey,
	o_orderdate,
	o_totalprice
order by
	o_totalprice desc,
	o_orderdate
LIMIT 100;
