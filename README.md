# Проект по анализу данных с помощью SQL
*В данном проекте используется PostgreSQL 16 и графический инструмент для управления базой данных pgAdmin4.*
### Ссылка на pptx файл с итоговым отчётом: 
## Исходные данные

1) customer_dim.csv (файл с данными о клиентах)
  - cust_id - уникальный идентификатор клиента
  - cust_address - адрес в формате "улица, город, почтовый индекс" (например, "335 Meadow St, Los Angeles, CA 90001")
  - cust_age - возраст клиента
  - effective_start_date - дата, когда запись о клиенте вступила в силу
  - effective_end_date - дата, когда запись о клиенте перестанет быть актуальной
  - current_ind - статус, который показывает актуальна ли сейчас запись о клиенте (Y/N)
2) product_dim.csv (файл с данными о товарах)
  - product_id - **не**уникальный идентификатор товара
  - product_name - наименование продукта
  - product_price - цена товара
  - effective_start_date - дата, когда запись о товаре вступила в силу
  - effective_end_date - дата, когда запись о товаре перестанет быть актуальной
  - current_ind - статус, который показывает актуальна ли сейчас запись о товаре (Y/N)
3) sales_transactions.csv
  - order_id - **не**уникальный идентификатор заказа
  - product_id - идентификатор товара (ссылается на product_dim)
  - cust_id - идентификатор покупателя (ссылается на customer_dim)
  - product_quantity - число единиц товара в заказе
  - order_date - дата офрмления заказа

## 1.Создание и импорт таблиц
*Весь код также есть в отдельном файле, в котором блоки кода сопровождаются комментариями с нумерацией и заголовками, соответствующими заголовкам с номерами в описании проекта*
Создаём базу данных и определяем таблицы, соответсвующие трём исходным файлам.
```sql
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
```
В 3 пункте будет подробнее объяснено, каким образом хранятся данные и почему в таблицах были использованы не уникальные идентификаторы.

Импорт данных в таблицы осуществляется с помощью операции импорта в pgAdmin4 (важно выбрать запятую в качестве разделителя и указать что csv файл содержит заголовки).
## 2.Проверка успешности импорта
Убедиться в том, что импорт прошёл успешно, можно выполнив каждый из следующих запросов.
```sql
select *
from customers_dim;
```
```sql
select *
from product_dim;
```
```sql
select *
from sales_transactions;
```
## 3.Особенности хранения данных
Обратимся к таблице customers_dim с запросом:
```sql
select distinct 
	effective_start_date, 
	effective_end_date, 
	current_ind 
from customers_dim;
```
Получим следующий результат:
|   | effective_start_date | effective_end_date | current_ind |
|---|----------------------|--------------------|-------------|
| 1 | 1900-01-01           | 9999-12-31         | Y           |

То есть в этих трёх колонках не хранится какой либо полезной информации.

Перейдём к таблице product_dim. Как было указано ранее, значения product_id не уникальны. Обратимся к конкретному продукту с помощью запроса
```sql
select *
from product_dim
where product_name = 'iPhone'
order by effective_start_date;
```
Имеем следующий результат:
|   |product_id|product_name                 |product_price|effective_start_date                         |effective_end_date|current_ind|
|---|----------|-----------------------------|-------------|---------------------------------------------|------------------|-----------|
|1  |582       |iPhone                       |700          |1900-01-01                                   |2019-03-31        |N          |
|2  |582       |iPhone                       |649          |2019-04-01                                   |2019-05-31        |N          |
|3  |582       |iPhone                       |689          |2019-06-01                                   |2019-09-30        |N          |
|4  |582       |iPhone                       |635          |2019-10-01                                   |2019-11-30        |N          |
|5  |582       |iPhone                       |620          |2019-12-01                                   |9999-12-31        |Y          |

То есть, в таблице строки с одинаковыми идентификаторами соответветствуют одному товару, но разным временным промежуткам и установленным на продукт ценам.

Далее рассмотрим таблицу sales_transactions. Используем следующий запрос:
```sql
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
```
Сначала с помощью внутреннего запроса (самого вложенного) группируем по order_id и считаем кол-во строк, соответствующих данному заказу. Далее выбираем один order_id с двумя и более строками в таблице. Используем полученное значение в качестве фильтра для внешнего запроса.
Получаем следующий результат:
| # |order_id|product_id|cust_id|product_quantity|order_date|
|---|--------|----------|-------|----------------|----------|
|1  |141275  |715       |199595 |1               |2019-01-07|
|2  |141275  |277       |199595 |1               |2019-01-07|

Это значит, что разным строкам с одинаковыми order_id соответствуют разные товары в одном заказе.

## 4.Очистка и преобразование данных
Удаляем несодержательные столбцы в таблице customers_dim.
```sql
alter table customers_dim drop column effective_start_date;
alter table customers_dim drop column effective_end_date;
alter table customers_dim drop column current_ind;
```
Также в этой таблице преобразуем адрес. Вместо полного адреса добавим столбцы с городом и штатом.
```sql
alter table customers_dim add column city varchar(20);
alter table customers_dim add column cust_state varchar(20);
```
Заполним город, зная, что адрес хранится в формате "улица, город, почтовый индекс". Строка разбивается на массив по разделителю ',' с помощью string_to_array. Затем лишний пробел убирается с помощью функции trim.
```sql
update customers_dim
set city = trim((string_to_array(cust_address, ','))[2]);
```
Также добавим штат (список городов получен с помощью запроса с distinct):
```sql
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
```
Теперь можно убрать столбец cust_adress, так как все необходимые для анализа сведения о местонахождении клиента находятся в новых столбцах.
```sql
alter table customers_dim drop column cust_address;
```
## 5.Анализ данных
### 5.0.Создание представления
В дальнейшем будут часто использованы запросы, в которых одновременно требуются данные из таблицы **sales_transactions** и **product_dim**. Для избежания повторений создадим представление с объединёнными таблицами. 
```sql
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
```
### 5.1.Список товаров с ценами, которые актуальны на данный момент
Получим этот список, отфильтруя по статусу **current_ind**.
```sql
select 
    product_name, 
    product_id, 
    product_price
from product_dim 
where current_ind = 'Y'
order by product_name
```
### 5.2.Число заказов и выручка по каждому товару 
```sql
select 
    product_name, 
    count(sp.order_id) as count_orders, 
    round((sum(sp.product_quantity * sp.product_price)/1e6)::numeric, 2)  as total_revenue_million
from sales_with_prod_info sp
group by product_name 
order by total_revenue_million desc;
```

### 5.3.Число заказов и выручка по каждому месяцу
```sql
select 
    extract(year from order_date) as y, 
    extract(month from order_date) as m,
    count(sp.order_id) as count_orders,
    round((sum(sp.product_quantity * sp.product_price)/1e6)::numeric, 2)  as total_revenue_millions
from sales_with_prod_info sp
group by extract(year from order_date), extract(month from order_date)
order by y, m;
```

### 5.4.Анализ покупателей по возрасту (минимальный, максимальный, средний и медианный возраст)
Данные сгруппированы по покупателю, затем получен результат с помощью агрегирующих функций. Закомментированная часть запроса гарантирует, что в таблице **customers_dim** нет записей о покупателях, которые не совершили ни одного заказа (при выполнении запроса с закомментированным кодом получаем значения null для всех функций).
```sql
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
```

### 5.5.Анализ выручки по двум возрастным группам 
Поделим покупателей на две возрастные группы, в одной из них будут покупатели с возрастом меньше медианного, в другой - больше.
```sql
with cte_cust_age as
    (
    select
        cust_id,
        cust_age - (select PERCENTILE_CONT(0.5) WITHIN GROUP(ORDER BY cust_age) 
		    from customers_dim) as age_diff
    from customers_dim 
    )
select 
    round(((sum(case when age_diff <= 0 then sp.product_quantity * sp.product_price 
		     else 0 end))/1e6)::numeric, 2) as revenue_million_younger_group,
    round(((sum(case when age_diff > 0 then sp.product_quantity * sp.product_price 
		     else 0 end))/1e6)::numeric, 2) as revenue_million_elder_group
from sales_with_prod_info sp
    join cte_cust_age c on c.cust_id = sp.cust_id;
```
CTE использован в запросе для упрощения читаемости кода. В нём содержится **cust_id** (для последующего присоединения к представлению **sales_with_prod_info**) и **age_diff** (разница между возрастом покупателя и медианным возврастом). Прибыль (в млн.) рассчитывается с помощью агрегации sum и разбита на две группы при помощи case выражения, в котором сравнивается значение **age_diff** с нулём.

### 5.6.Количество дней, которое в среднем проходит между заказами клиента
```sql
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
```
В **cte_days_between_purchase** запрос разбит на окна по cust_id, в которых строки отсортированы по order_date. Таким образом с помощью функции **lag()** можно получить предыдущую дату покупки у конкретного покупателя и вычислить разницу между ними. 

При этом подзапрос оставляет только одну строку с информацией о каждом заказе с датой и id клиента. Если этого не сделать для заказазов с двумя и более разными товарами оконная функция вернёт дату предыдущего заказа только для первой строки конкретного заказа, а для последующих будет возвращена дата текущего заказа. Таким образом разница дат в этих строках будет равна 0, что не соответствует действительности.

После вычисления разниц дат между заказами каждого клиента во внешнем запросе фильтруем строки где **days_from_last_purchase** не равны *null*, таким образом не учитываются первые заказы у каждого клиента (для которых не существует предыдущего заказа, соответственно не может быть рассчитанна разница с датой предыдущего заказа), и агрегируем с помощью соответсвующих агрегатных функций.

### 5.7.Топ 5 товаров по выручке для каждого штата
```sql
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
from(
    select 
	cust_state, 
	product_name,
	revenue_per_state_and_product as revenue_thousand,
	row_number() over(partition by cust_state order by revenue_per_state_and_product desc) as revenue_rank
    from sales_cte) as sales_rank
where revenue_rank <= 5
```
В **sales_cte** рассчитывается выручка (в тыс.) по каждому продукту в каждом штате. Затем в подзапросе (после from) каждому продукту присваивается ранг по прибыли в каждом штате с помощью оконной функции row_number с сортировкой по **revenue_per_state_and_product** в порядке убывания. Наконец, во внешнем запросе остаются только строки с рангом равным 5 или менее.

### 5.8.Число клиентов, совершивших по крайней мере 5 заказов
```sql
select count(*)
from(
    select 1
    from sales_transactions s
	join customers_dim c on s.cust_id = c.cust_id
    group by c.cust_id
    having count(*) >= 5
    ) as active_customers
```
