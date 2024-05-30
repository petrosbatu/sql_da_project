--1.Создание таблиц и импорт данных 
create table customers_dim
(
	cust_id integer primary key,
	cust_address varchar(100),
	cust_age smallint,
	effective_start_date date,
	effective_end_date date,
	current_ind varchar(1)
);


create table product_dim 
(
	product_id smallint, --не используется PK, так как значение не уникально
	product_name varchar(50),
	product_price real,
	effective_start_date date,
	effective_end_date date,
	current_ind varchar(1)
);

create table sales_transactions
(
	order_id integer, --не используется PK, так как значение не уникально
	product_id integer, --не используется FK, так как значение product_id в таблице product_dim не уникально
	cust_id integer references customers_dim(cust_id),
	product_quantity smallint,
	order_date date
);


--2.Проверка успешности импорта
select *
from customers_dim;


select *
from product_dim;


select *
from sales_transactions;

--3.Особенности данных

select distinct 
	effective_start_date, 
	effective_end_date, 
	current_ind 
from customers_dim; 

select *
from product_dim
where product_name = 'iPhone'
order by effective_start_date;


select distinct effective_start_date, effective_end_date 
from product_dim;

select *
from sales_transactions
where order_id = (
	select order_id
	from(
		select order_id, count(*) as cnt_products_in_order
		from sales_transactions
		group by order_id
		) as subquery
	where cnt_products_in_order > 1
	limit 1
	)

--4.Очистка и преобразование данных 
alter table customers_dim drop column effective_start_date;
alter table customers_dim drop column effective_end_date;
alter table customers_dim drop column current_ind;


alter table customers_dim add column city varchar(20);
alter table customers_dim add column cust_state varchar(20);

update customers_dim
set city = trim((string_to_array(cust_address, ','))[2]);

update customers_dim
set cust_state = 
	(case when city in ('Seattle') then 'Washington'
		when city in ('San Francisco', 'Los Angeles') then 'California'
		when city in ('Portland') then 'Oregon'
		when city in ('Atlanta') then 'Georgia, U.S.'
		when city in ('Boston') then 'Massachusetts'
		when city in ('Dallas', 'Austin') then 'Massachusetts'
		when city in ('New York City') then 'New York state'
		else 'not defined'
	end);


alter table customers_dim drop column cust_address;

--5.Анализ данных
--5.0. Создание представления
create view sales_with_prod_info as
	(
	select 
		s.*,
		p.product_name,
		p.product_price,
		p.effective_start_date,
		p.effective_end_date
	from sales_transactions s 
		join product_dim p on s.product_id = p.product_id
	where s.order_date between p.effective_start_date and p.effective_end_date 
	)

	
--5.1.Список товаров с ценами, которые актуальны "на данный момент"
select 
	product_name,  
	product_price
from product_dim 
where current_ind = 'Y'
order by product_name


--5.2.Число заказов и выручка по каждому товару 
select 
	product_name, 
	count(sp.order_id) as count_orders, 
	round((sum(sp.product_quantity * sp.product_price)/1e6)::numeric, 2)  as total_revenue_million
from sales_with_prod_info sp
group by product_name 
order by total_revenue_million desc;


--5.3.число заказов и выручка по каждому месяцу + накопительные
select 
	extract(year from order_date) as y, 
	extract(month from order_date) as m,
	count(sp.order_id) as count_orders,
	round((sum(sp.product_quantity * sp.product_price)/1e6)::numeric, 2)  as total_revenue_millions
from sales_with_prod_info sp
group by extract(year from order_date), extract(month from order_date)
order by y, m;


select 
	y,
	m,
	sum(count_orders) over(order by y, m) as count_orders,
	sum(total_revenue_millions) over(order by y, m) as total_revenue_millions
from (
	select 
		extract(year from order_date) as y, 
		extract(month from order_date) as m,
		count(sp.order_id) as count_orders,
		round((sum(sp.product_quantity * sp.product_price)/1e6)::numeric, 2)  as total_revenue_millions
	from sales_with_prod_info sp
	group by extract(year from order_date), extract(month from order_date)
	)

--5.4.Анализ покупателей по возрасту (минимальный, максимальный, средний и медианный возраст)
select 
	PERCENTILE_CONT(0.5) WITHIN GROUP(ORDER BY cust_age) as median_age,
	round(avg(cust_age)) as mean_age,
	min(cust_age) as min_age,
	max(cust_age) as max_age
from customers_dim c;
/*where not exists (
	select 1 
	from sales_transactions s
	where s.cust_id = c.cust_id);
*/


--5.5.Анализ выручки по восьми возрастным группам
with cte_cust_age as
	(
	select
		cust_id,
		cust_age,
		ntile(16) over(order by cust_age) as age_group
	from customers_dim 
	)
select
	age_group,
	min(cust_age),
	max(cust_age),
	round((sum(sp.product_price * sp.product_quantity)/1e6)::numeric, 2) as revenue_millions
from sales_with_prod_info sp
	join cte_cust_age c on c.cust_id = sp.cust_id
group by age_group
order by age_group


--5.6.Количество дней, которое в среднем проходит между заказами клиента
with cte_days_between_purchase as
	(
	select 
		order_date - lag(order_date) over(partition by cust_id order by order_date) as days_from_last_purchase
	from
		(select distinct 
			order_id,
			cust_id,
			order_date
		from sales_transactions) as sales_dates
	)
select 
	round(avg(days_from_last_purchase)) avg_days_between_purchase,
	PERCENTILE_CONT(0.5) WITHIN GROUP(ORDER BY days_from_last_purchase) as median_days_between_purchase 
from cte_days_between_purchase
where days_from_last_purchase is not null


--5.7.Топ 5 товаров по выручке для каждого штата
with sales_cte as
	(
	select 
		c.cust_state, 
		sp.product_name,
		round(sum(sp.product_quantity * sp.product_price)/1e3) as revenue_per_state_and_product
	from sales_with_prod_info sp 
		join customers_dim c on sp.cust_id = c.cust_id
	group by c.cust_state, sp.product_name
	)
select 
	*
from (
	  select 
		  cust_state, 
		  product_name,
		  revenue_per_state_and_product as revenue_thousand,
		  row_number() over(partition by cust_state order by revenue_per_state_and_product desc) as revenue_rank
	   from sales_cte) as sales_rank
where revenue_rank <= 5


--5.8.Число клиентов, совершивших по крайней мере 5 заказов
select count(*) as cnt_active_customers
from(
	select 1
	from sales_transactions s
		join customers_dim c on s.cust_id = c.cust_id
	group by c.cust_id
	having count(*) >= 5
	) as active_customers

--5.9.Самые популярные пары товаров в заказе	
select 
	sp1.product_name as product1,
	sp2.product_name as product2,
	count(*) as cnt_orders
from sales_with_prod_info sp1
	join sales_with_prod_info sp2 on sp1.order_id = sp2.order_id
where sp1.product_name < sp2.product_name
group by sp1.product_name, sp2.product_name
order by count(*) desc
limit 10



--5.10.Товары, которые чаще всего покупают вместе с другими товарами
with 
	combinations as
		(
		select 
			sp1.product_name as product1,
			sp2.product_name as product2,
			count(*) as cnt_orders
		from sales_with_prod_info sp1
			join sales_with_prod_info sp2 on sp1.order_id = sp2.order_id
		where sp1.product_name < sp2.product_name
		group by sp1.product_name, sp2.product_name
		)
	,
	product_list as
		(
		select distinct
			product_name
		from product_dim
		)
select
	p.product_name,
	sum(c.cnt_orders) as orders
from combinations c
	join product_list p on (p.product_name = c.product1 or p.product_name = c.product2)
group by p.product_name
order by orders desc
limit 10