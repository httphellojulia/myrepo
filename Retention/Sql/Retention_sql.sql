select *
from crosstab(
'with tbl as(select user_id, date(shipped_at) as order_date, date(min(shipped_at) over (partition by user_id)) as first_order from orders),
tbl2 as (select user_id,order_date,first_order, dense_rank() over (partition by date_trunc(''month'',first_order), date_trunc(''month'', order_date) order by user_id) as user_rnk, dense_rank() over (partition by date_trunc(''month'',first_order) order by date_trunc(''month'', order_date)) as month_rank from tbl),
tbl3 as (select date_trunc(''month'',first_order) as fo, date_trunc(''month'',order_date) as od, max(user_rnk) as user_count, month_rank  from tbl2 group by 1,2, month_rank order by 1,2)
select date(fo) as first_order, month_rank, round(lead(user_count) OVER(partition by fo ORDER BY fo) / first_value(user_count) OVER(partition by fo ORDER BY fo)::numeric*100,2) as retention from tbl3',
'select generate_series(1,16)')
as ct(first_order text,
    "1" text, "2" text, "3" text, "4" text, "5" text
       , "6" text,"7" text, "8" text, "9" text,"10" text
       , "11" text, "12" text,"13" text, "14" text, "15" text
       , "16" text)
