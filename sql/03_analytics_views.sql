--------------------------------------------------------------------------------------------------------------
-- СКРИПТ СОЗДАНИЯ АНАЛИТИЧЕСКИХ ПРЕДСТАВЛЕНИЙ (VIEW)
-- Цель: очистка типов данных, создание витрин фактов и измерений для Power BI.
--------------------------------------------------------------------------------------------------------------
CREATE SCHEMA IF NOT EXISTS analytics;
--------------------------------------------------------------------------------------------------------------
-- 1. ОЧИЩЕННЫЕ ТАБЛИЦЫ (STAGING LAYER)
--------------------------------------------------------------------------------------------------------------
----------

-- 1.1. Заказы
CREATE OR REPLACE VIEW analytics.orders AS
SELECT
    TRIM(order_id) AS order_id,
    NULLIF(TRIM(customer_id), '') AS customer_id,
    NULLIF(TRIM(order_status), '') AS order_status,

    NULLIF(TRIM(order_purchase_timestamp), '')::timestamp
        AS order_purchase_timestamp,

    NULLIF(TRIM(order_approved_at), '')::timestamp
        AS order_approved_at,

    NULLIF(TRIM(order_delivered_carrier_date), '')::timestamp
        AS order_delivered_carrier_date,

    NULLIF(TRIM(order_delivered_customer_date), '')::timestamp
        AS order_delivered_customer_date,

    NULLIF(TRIM(order_estimated_delivery_date), '')::timestamp
        AS order_estimated_delivery_date

FROM raw.orders
WHERE NULLIF(TRIM(order_id), '') IS NOT NULL;
--------------------------------------------------------------------------------------------------------------
-- 1.2. Позиции заказов
CREATE OR REPLACE VIEW analytics.order_items AS
SELECT
    TRIM(order_id) AS order_id,
    NULLIF(TRIM(order_item_id), '')::integer AS order_item_id,
    NULLIF(TRIM(product_id), '') AS product_id,
    NULLIF(TRIM(seller_id), '') AS seller_id,

    NULLIF(TRIM(shipping_limit_date), '')::timestamp
        AS shipping_limit_date,

    NULLIF(TRIM(price), '')::numeric(12,2) AS price,
    NULLIF(TRIM(freight_value), '')::numeric(12,2)
        AS freight_value

FROM raw.order_items
WHERE NULLIF(TRIM(order_id), '') IS NOT NULL;
--------------------------------------------------------------------------------------------------------------
-- 1.3. Клиенты
CREATE OR REPLACE VIEW analytics.customers AS
SELECT
    TRIM(customer_id) AS customer_id,
    NULLIF(TRIM(customer_unique_id), '') AS customer_unique_id,
    NULLIF(TRIM(customer_zip_code_prefix), '') AS zip_code_prefix,
    NULLIF(TRIM(customer_city), '') AS customer_city,
    NULLIF(TRIM(customer_state), '') AS customer_state
FROM raw.customers
WHERE NULLIF(TRIM(customer_id), '') IS NOT NULL;
--------------------------------------------------------------------------------------------------------------
-- 1.4. Товары
CREATE OR REPLACE VIEW analytics.products AS
SELECT
    TRIM(product_id) AS product_id,
    NULLIF(TRIM(product_category_name), '') AS product_category_name,
    NULLIF(TRIM(product_weight_g), '')::numeric AS weight_g,
    NULLIF(TRIM(product_length_cm), '')::numeric AS length_cm,
    NULLIF(TRIM(product_height_cm), '')::numeric AS height_cm,
    NULLIF(TRIM(product_width_cm), '')::numeric AS width_cm
FROM raw.products
WHERE NULLIF(TRIM(product_id), '') IS NOT NULL;
--------------------------------------------------------------------------------------------------------------
-- 1.5. Отзывы
CREATE OR REPLACE VIEW analytics.reviews AS
SELECT
    TRIM(review_id) AS review_id,
    NULLIF(TRIM(order_id), '') AS order_id,
    NULLIF(TRIM(review_score), '')::integer AS review_score,
    NULLIF(TRIM(review_creation_date), '')::timestamp
        AS review_creation_date,
    NULLIF(TRIM(review_answer_timestamp), '')::timestamp
        AS review_answer_timestamp
FROM raw.reviews
WHERE NULLIF(TRIM(review_id), '') IS NOT NULL;
--------------------------------------------------------------------------------------------------------------
-- 1.6. Перевод категорий
CREATE OR REPLACE VIEW analytics.category_translation AS
SELECT
    NULLIF(TRIM(product_category_name), '') AS product_category_name,
    NULLIF(TRIM(product_category_name_english), '') AS product_category_name_english
FROM raw.category_translation;
--------------------------------------------------------------------------------------------------------------
-- 2. СОЗДАНИЕ ВИТРИН ДАННЫХ (FACT TABLES)
--------------------------------------------------------------------------------------------------------------
----------

-- 2.1. Витрина "Позиции заказов" (fact_order_items — одна строка = одна позиция в заказе)
CREATE OR REPLACE VIEW analytics.fact_order_items AS
SELECT
    i.order_id,
    i.order_item_id,
    i.product_id,
    i.seller_id,
    o.customer_id,
    c.customer_unique_id,
    o.order_status,
    o.order_purchase_timestamp,
    i.price,
    i.freight_value,
    p.product_category_name,
    t.product_category_name_english
FROM analytics.order_items i
JOIN analytics.orders o
    ON i.order_id = o.order_id
LEFT JOIN analytics.customers c
    ON o.customer_id = c.customer_id
LEFT JOIN analytics.products p
    ON i.product_id = p.product_id
LEFT JOIN analytics.category_translation t
    ON p.product_category_name = t.product_category_name;
--------------------------------------------------------------------------------------------------------------
-- 2.2. Агрегация отзывов (убираем дубли через DISTINCT и считаем среднюю оценку)
CREATE OR REPLACE VIEW analytics.reviews_by_order AS
SELECT
    order_id,
    AVG(review_score)::numeric(3,2) AS average_review_score,
    COUNT(DISTINCT review_id) AS review_record_count
FROM (
    SELECT DISTINCT review_id, order_id, review_score 
    FROM analytics.reviews
    WHERE review_score BETWEEN 1 AND 5
) AS unique_reviews
GROUP BY order_id;
-------------------------------------------------------------------------------------------------------------
-- 2.3. Витрина "Заказы" (fact_orders — одна строка = один заказ)
CREATE OR REPLACE VIEW analytics.fact_orders AS
SELECT
    o.order_id,
    o.customer_id,
    c.customer_unique_id,
    o.order_status,
    o.order_purchase_timestamp,
    o.order_approved_at,
    o.order_delivered_carrier_date,
    o.order_delivered_customer_date,
    o.order_estimated_delivery_date,
    CASE
        WHEN o.order_status = 'delivered'
         AND o.order_delivered_customer_date IS NOT NULL
         AND o.order_estimated_delivery_date IS NOT NULL
        THEN
            o.order_delivered_customer_date
                <= o.order_estimated_delivery_date
        ELSE NULL
    END AS delivered_on_time,
    r.average_review_score,
    r.review_record_count
FROM analytics.orders o
LEFT JOIN analytics.customers c
    ON o.customer_id = c.customer_id
LEFT JOIN analytics.reviews_by_order r
    ON o.order_id = r.order_id;
--------------------------------------------------------------------------------------------------------------
-- 3. ВАЛИДАЦИЯ ДАННЫХ 
--------------------------------------------------------------------------------------------------------------
----------

-- 3.1. Проверка количества строк в витрине заказов
SELECT
    COUNT(*) AS rows,
    COUNT(DISTINCT order_id) AS distinct_orders
FROM analytics.fact_orders;

-- 3.2. Проверка количества строк в витрине позиций
SELECT
    COUNT(*) AS item_rows,
    COUNT(DISTINCT order_id) AS distinct_orders
FROM analytics.fact_order_items;

-- 3.3. Сверка выручки и стоимости доставки по доставленным заказам
SELECT
    SUM(price) AS all_item_value,
    SUM(freight_value) AS all_freight_value
FROM analytics.fact_order_items
WHERE order_status = 'delivered';