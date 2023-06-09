:EXPLAIN_ANALYZE
:CREATE_TABLE
:INSERT_TABLE
-- using 1686115892 as a seed to the RNG


select
	l_returnflag,
	l_linestatus,
	round(sum(l_quantity)) as sum_qty,
	round(sum(l_extendedprice)) as sum_base_price,
	round(sum(l_extendedprice * (1 - l_discount))) as sum_disc_price,
	round(sum(l_extendedprice * (1 - l_discount) * (1 + l_tax))) as sum_charge,
	round(avg(l_quantity)) as avg_qty,
	round(avg(l_extendedprice)) as avg_price,
	round(avg(l_discount)) as avg_disc,
	count(*) as count_order
from
	lineitem
where
	l_shipdate <= date '1998-12-01' - interval '90 days'
group by
	l_returnflag,
	l_linestatus
order by
	l_returnflag,
	l_linestatus;
