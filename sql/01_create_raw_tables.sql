--------------------------------------------------------------------------------------------------------------
-- Скрипт создает схему raw и таблицы для загрузки исходных данных датасета Olist.

CREATE SCHEMA IF NOT EXISTS raw;
--------------------------------------------------------------------------------------------------------------
-- Создание сырых таблиц

CREATE TABLE raw.orders (
    order_id TEXT,
    customer_id TEXT,
    order_status TEXT,
    order_purchase_timestamp TEXT,
    order_approved_at TEXT,
    order_delivered_carrier_date TEXT,
    order_delivered_customer_date TEXT,
    order_estimated_delivery_date TEXT
);

CREATE TABLE raw.order_items (
    order_id TEXT,
    order_item_id TEXT,
    product_id TEXT,
    seller_id TEXT,
    shipping_limit_date TEXT,
    price TEXT,
    freight_value TEXT
);

CREATE TABLE raw.customers (
    customer_id TEXT,
    customer_unique_id TEXT,
    customer_zip_code_prefix TEXT,
    customer_city TEXT,
    customer_state TEXT
);

CREATE TABLE raw.products (
    product_id TEXT,
    product_category_name TEXT,
    product_name_lenght TEXT,
    product_description_lenght TEXT,
    product_photos_qty TEXT,
    product_weight_g TEXT,
    product_length_cm TEXT,
    product_height_cm TEXT,
    product_width_cm TEXT
);

CREATE TABLE raw.reviews (
    review_id TEXT,
    order_id TEXT,
    review_score TEXT,
    review_comment_title TEXT,
    review_comment_message TEXT,
    review_creation_date TEXT,
    review_answer_timestamp TEXT
);

CREATE TABLE raw.category_translation (
    product_category_name TEXT,
    product_category_name_english TEXT
);

CREATE TABLE IF NOT EXISTS raw.order_payments (
    order_id              VARCHAR(50),
    payment_sequential    INTEGER,
    payment_type          VARCHAR(50),
    payment_installments  INTEGER,
    payment_value         NUMERIC(12, 2)
);
--------------------------------------------------------------------------------------------------------------
--Проверка, что данные загрузились корректно (вывод количества строк по всем таблицам)

SELECT 'orders' AS table_name, COUNT(*) AS row_count
FROM raw.orders

UNION ALL

SELECT 'order_items', COUNT(*)
FROM raw.order_items

UNION ALL

SELECT 'customers', COUNT(*)
FROM raw.customers

UNION ALL

SELECT 'products', COUNT(*)
FROM raw.products

UNION ALL

SELECT 'reviews', COUNT(*)
FROM raw.reviews

UNION ALL

SELECT 'category_translation', COUNT(*)
FROM raw.category_translation

UNION ALL

SELECT 'order_payments', COUNT(*)
FROM raw.order_payments;
--------------------------------------------------------------------------------------------------------------
-- Выборочный просмотр первых 5 строк для проверки структуры

SELECT *
FROM raw.orders
LIMIT 5;

SELECT *
FROM raw.order_items
LIMIT 5;

SELECT *
FROM raw.customers
LIMIT 5;

SELECT *
FROM raw.products
LIMIT 5;

SELECT *
FROM raw.reviews
LIMIT 5;

SELECT *
FROM raw.category_translation
LIMIT 5;

SELECT *
FROM raw.order_payments
LIMIT 5;
--------------------------------------------------------------------------------------------------------------