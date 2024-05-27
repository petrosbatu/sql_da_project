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

Это значит, что разным строкам с одинаковыми order_id соответствуют разные товары в заказе.

## 4.Очистка и преобразование данных
