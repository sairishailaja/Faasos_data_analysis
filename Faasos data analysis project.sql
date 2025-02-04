select * from customer_orders;
select * from driver_order;
select * from ingredients;
select * from driver;
select * from rolls;
select * from rolls_recipes;

-- 1. Roll metrics
-- a) Total number of rolls ordered:
select count(roll_id) from customer_orders;

-- b) Total count of unique customer orders:
select distinct customer_id from customer_orders;

-- c) Total number of successful orders delivered by each driver:
select  driver_id ,count(distinct order_id) as successful_orders from driver_order where cancellation not in ('Cancellation','Customer Cancellation') 
group by driver_id;

-- d) The quantity of each type of roll that was delivered:
select roll_id,count( roll_id)from
customer_orders where order_id in (
select order_id from
(select *,case when cancellation in  ('cancellation','customer cancellation') then 'c'else 'nc' end as order_cancel_details from driver_order)a
where order_cancel_details='nc')
group by roll_id;

-- e) The number of veg and non-veg Rolls were ordered by each customer:
select a. * ,b.roll_name from
(select customer_id, roll_id,count(roll_id) from customer_orders group by customer_id, roll_id)
a inner join rolls b on a.roll_id=b.roll_id;

-- f) maximum number of rolls delivered by the single order:
select order_id,count(roll_id) from 
customer_orders where order_id in (
select order_id from
(select *, case when cancellation in ('cancellation','customer cancellation')then 'c'else 'nc' end as order_cancel_details from driver_order)a
where order_cancel_details='nc')
group by order_id;

-- g) The number of delivered rolls for each customer that had at least one change and the number that had no changes:
with temp_customer_orders(order_id,customer_id,roll_id,not_include_items,extra_items_included,order_date) as
(
select order_id, customer_id,roll_id ,
case when not_include_items is null or not_include_items= '' then '0' else not_include_items end as new_not_include_items,
case when extra_items_included is null or extra_items_included = '' or extra_items_included = 'NaN' or extra_items_included= 'NULL' then '0' else extra_items_included  end as new_extra_items_included,
order_date from customer_orders
)
,
temp_driver_order(order_id,driver_id,pickup_time,distance,duration,new_cancellation) as
(
select order_id, driver_id,pickup_time ,distance,duration,
case when cancellation in ('Cancellation','Customer Cancellation')then '0' else 1 end as new_cancellation
from driver_order
)
select customer_id, chg_no_chg, count(order_id) at_least_1_change from 
(
select *, case when not_include_items = '0'and extra_items_included ='0' then 'no change' else 'change' end chg_no_chg
from temp_customer_orders where order_id in ( 
select order_id from temp_driver_order WHERE new_cancellation <> 0))a
group by customer_id, chg_no_chg;

-- h) The total number of rolls delivered with both exclusions and extras:
with temp_customer_orders(order_id,customer_id,roll_id,not_include_items,extra_items_included,order_date) as
(
select order_id, customer_id,roll_id ,
case when not_include_items is null or not_include_items= '' then '0' else not_include_items end as new_not_include_items,
case when extra_items_included is null or extra_items_included = '' or extra_items_included = 'NaN' or extra_items_included= 'NULL' then '0' else extra_items_included  end as new_extra_items_included,
order_date from customer_orders
)
,
temp_driver_order(order_id,driver_id,pickup_time,distance,duration,new_cancellation) as
(
select order_id, driver_id,pickup_time ,distance,duration,
case when cancellation in ('Cancellation','Customer Cancellation')then '0' else 1 end as new_cancellation
from driver_order
)
select chg_no_chg, count(chg_no_chg) from
(select *, case when not_include_items <> '0'and extra_items_included <>'0' then 'orders with both exclusions and extras' else 'orders with either 1 exclusion or extra' end chg_no_chg
from temp_customer_orders where order_id in ( 
select order_id from temp_driver_order WHERE new_cancellation <> 0))
group by chg_no_chg;

-- i) The total number of rolls ordered by each hour of the day:
select
hours_bucket,count(hours_bucket)from
(select * ,
(cast (DATE_PART ('hour', order_date) as varchar)|| '-' ||cast (DATE_PART ('hour', order_date)+ 1 as varchar) ) hours_bucket from customer_orders)a
group by hours_bucket;

-- j) The total number of rolls ordered by each day of the week:
select date_of_order,count(distinct order_id) from
(select * ,TO_CHAR (order_date,'Day') as date_of_order from customer_orders)a
group by date_of_order;


-- 2.driver and customer experience
-- a) The average time in minutes it took for each driver to arrive at the fasoos HQ to pickup the order:
-- joining two tables>>
select a.order_id,
       a.customer_id, 
	   a.roll_id, 
	   a.not_include_items, 
	   a.extra_items_included, 
	   a.order_date,
       b.driver_id,
	   b.pickup_time,
	   b.distance,
	   b.duration,
	   b.cancellation 
	   from customer_orders as a inner join driver_order as b on a.order_id=b.order_id
	   
	   
select driver_id, sum(diff)/count(order_id) avg_mins from
(select * from
(select*, row_number() over(partition by order_id order by diff)rnk from
(select a.order_id,
        a.customer_id, 
	    a.roll_id, 
	    a.not_include_items, 
	    a.extra_items_included, 
	    a.order_date,
        b.driver_id,
	    b.pickup_time,
	    b.distance,
	    b.duration,
	    b.cancellation,
	    ABS (extract(epoch from(b.pickup_time-a.order_date))/60) as diff
	   from customer_orders as a inner join driver_order as b on a.order_id=b.order_id where pickup_time is not null)a)b where rnk=1)c
	   group by driver_id;	 
	   
-- b) The relationship between the number of rolls and the order preparation time can be analyzed:
select order_id, count(roll_id)cnt ,sum(diff)/count(roll_id) tym from
(select a.order_id,
       a.customer_id, 
	   a.roll_id, 
	   a.not_include_items, 
	   a.extra_items_included, 
	   a.order_date,
       b.driver_id,
	   b.pickup_time,
	   b.distance,
	   b.duration,
	   b.cancellation,
	   ABS (extract(epoch from(b.pickup_time-a.order_date))/60) as diff
	   from customer_orders as a inner join driver_order as b on a.order_id=b.order_id where pickup_time is not null)a
	   group by order_id;
	  
-- c) The average distance travelled for each customer_order:
select customer_id,sum(distance)/count(order_id) avg_distance from
(select * from
(select*, row_number() over(partition by order_id order by diff)rnk from
(select a.order_id,
       a.customer_id, 
	   a.roll_id, 
	   a.not_include_items, 
	   a.extra_items_included, 
	   a.order_date,
       b.driver_id,
	   b.pickup_time,
	   cast (trim(replace(lower(distance),'km',''))as decimal(4,2)) as distance,
	   b.duration,
	   b.cancellation,
	    ABS (extract(epoch from(b.pickup_time-a.order_date))/60) as diff
	   from customer_orders as a inner join driver_order as b on a.order_id=b.order_id where b.pickup_time is not null)a)b where rnk=1)c
	   group by customer_id;
	   
-- d) difference between the longest and shortest delivery times for all orders: 
select max(duration_numeric)-min(duration_numeric) as duration_difference from(
select case
	when duration is null or duration = '' Then null 
	when duration like'%min%'  then cast (left(duration,position('m' in duration)-1) as integer)
	else cast(duration as integer) end as duration_numeric from  driver_order) as subquery where duration_numeric is not null;  
	
-- e) The average speed of each driver for each delivery and noticeable trends in these values:
select a.order_id,a.driver_id,a.distance/a.duration speed,b.cnt from
(select order_id,driver_id, cast (trim(replace(lower(distance),'km',''))as decimal(4,2)) as distance,
cast (case when duration like'%min%'  then left(duration,position('m' in duration)-1)else
duration end as integer) as duration from  driver_order where distance is not null)a inner join
(select order_id,count(roll_id) cnt from customer_orders group by order_id) b on a.order_id=b.order_id ;

-- f) successful delivery percentage for each driver:
-- sdp = total orders successful delivered / total orders taken
select driver_id,succ_orders*1.0/total_or_taken cancelled_per from
(select driver_id, sum(can_per)succ_orders, count(driver_id) total_or_taken from
(select driver_id ,case when lower (cancellation) like' %cancel%' then 0 else 1 end as can_per from driver_order)a
group by driver_id)b;