ALTER TABLE supplier ADD CONSTRAINT supplier_nation_fk FOREIGN KEY (s_nationkey) REFERENCES nation (n_nationkey);
ALTER TABLE partsupp ADD CONSTRAINT partsupp_part_fk FOREIGN KEY (ps_partkey) REFERENCES part (p_partkey);
ALTER TABLE partsupp ADD CONSTRAINT partsupp_supplier_fk FOREIGN KEY (ps_suppkey) REFERENCES supplier (s_suppkey);
ALTER TABLE customer ADD CONSTRAINT customer_nation_fk FOREIGN KEY (c_nationkey) REFERENCES nation (n_nationkey);
ALTER TABLE orders ADD CONSTRAINT orders_customer_fk FOREIGN KEY (o_custkey) REFERENCES customer (c_custkey);
ALTER TABLE lineitem ADD CONSTRAINT lineitem_order_fk FOREIGN KEY (l_orderkey) REFERENCES orders (o_orderkey);
ALTER TABLE lineitem ADD CONSTRAINT lineitem_part_fk FOREIGN KEY (l_partkey) REFERENCES part (p_partkey);
ALTER TABLE lineitem ADD CONSTRAINT lineitem_partsupp_fk FOREIGN KEY (l_partkey, l_suppkey) REFERENCES partsupp (ps_partkey, ps_suppkey);
ALTER TABLE nation ADD CONSTRAINT nation_region_fk FOREIGN KEY (n_regionkey) REFERENCES region (r_regionkey);
