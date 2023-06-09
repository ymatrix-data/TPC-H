:EXPLAIN_ANALYZE
:CREATE_TABLE
:INSERT_TABLE
-- using 1686115892 as a seed to the RNG


select
	cntrycode,
	count(*) as numcust,
	round(sum(c_acctbal)) as totacctbal
from
	(
		select
			substring(c_phone from 1 for 2) as cntrycode,
			c_acctbal
		from
			customer
		where
			substring(c_phone from 1 for 2) in
				('23', '17', '20', '31', '13', '10', '28')
			and c_acctbal > (
				select
					avg(c_acctbal)
				from
					customer
				where
					c_acctbal > 0.00
					and substring(c_phone from 1 for 2) in
						('23', '17', '20', '31', '13', '10', '28')
			)
			and not exists (
				select
					*
				from
					orders
				where
					o_custkey = c_custkey
			)
	) as custsale
group by
	cntrycode
order by
	cntrycode;
