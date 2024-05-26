# Проект по анализу данных с помощью SQL
*В данном проекте используется PostgreSQL 16 и рафический инструмент для управления базой данных pgAdmin4.*
### Ссылка на pptx файл с итоговым отчётом: 
## Исходные данные
*Более подробно в ...*

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

Импорт данных в таблицы осуществляется операции импорта в pgAdmin4.
