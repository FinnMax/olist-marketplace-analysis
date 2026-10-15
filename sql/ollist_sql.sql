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
FROM raw.category_translation;

SELECT * FROM raw.orders LIMIT 3;

SELECT * FROM raw.order_items LIMIT 2;

SELECT * FROM raw.customers LIMIT 2;

SELECT * FROM raw.products LIMIT 2;

SELECT * FROM raw.reviews LIMIT 2;

SELECT * FROM raw.category_translation LIMIT 2;
--The import was successfull--
--------------------------------------------------------------------------------------------------------------
--raw.orders analysis--
	
	--1. Duplicates check--
SELECT order_id, COUNT(*) as occurences
FROM raw.orders
GROUP BY order_id
HAVING COUNT(*) > 1;
	--No duplicates found--
	
	--2. Check missing order ID--
SELECT COUNT(*) as missing_order_ids
FROM raw.orders
WHERE order_id IS NULL
	OR TRIM(order_id) = '';
	--No missing order ID--
	
	--3. Check order statuses--
SELECT order_status, COUNT(order_id) as number_of_orders
FROM raw.orders
GROUP BY order_status
ORDER BY COUNT(order_id) DESC;
	--Majority of orders have delivered status--
	
	--4. Check customer references
SELECT COUNT(*) AS unmatched_customers
FROM raw.orders o
LEFT JOIN raw.customers c
ON o.customer_id = c.customer_id
WHERE c.customer_id IS NULL;
--No missing values have been found--
--------------------------------------------------------------------------------------------------------------
--raw.order_items analysis--
SELECT *
FROM raw.order_items
LIMIT 3;

	--1. Duplicates check--
WITH multiple_items_orders AS (
	SELECT order_id, COUNT(DISTINCT(product_id)) as number_of_products, COUNT(*) as appearances
	FROM raw.order_items
	GROUP BY order_id
	HAVING COUNT(*) > 1
)
SELECT *
FROM multiple_items_orders;
	--A lot of duplicates in order_id, which means multiple items per order--
	
	--2. Price format check--
SELECT *
FROM raw.order_items
WHERE NULLIF(TRIM(price), '') IS NULL
OR TRIM(price) !~ '^[0-9]+(\.[0-9]+)?$'
LIMIT 50;
	--No invalid price formats
	
	--2.1 Freight value format check--
SELECT *
FROM raw.order_items
WHERE NULLIF(TRIM(freight_value), '') IS NULL
OR TRIM(freight_value) !~ '^[0-9]+(\.[0-9]+)?$'
LIMIT 50;
	--No invalid freight value formats

	--3. Missing values check--
SELECT COUNT(*) as missing_order_id
FROM raw.order_items
WHERE order_id IS NULL
OR TRIM(order_id) = '';
	--No missing values of order_id--
--------------------------------------------------------------------------------------------------------------
--raw.customers analysis--
	--1. Duplicates check--
SELECT customer_id, COUNT(*) as appearances
FROM raw.customers
GROUP BY customer_id
HAVING COUNT(*) > 1;
--No duplicates in customer_id--

	--1.1 Duplicates check(customer_unique_id)
SELECT customer_unique_id, COUNT(*) as appearances
FROM raw.customers
GROUP BY customer_unique_id
HAVING COUNT(*) > 1;
--Means that 2997 customers did orders more than once--

	--2. Missing values check--
SELECT COUNT(*)
FROM raw.customers
WHERE customer_id IS NULL
OR customer_unique_id IS NULL;
--No missing values in customer_id and customer_unique_id--
--------------------------------------------------------------------------------------------------------------
	--raw.products analysis--
	--1. Duplicates check--
SELECT product_id, COUNT(*) as appearances
FROM raw.products
GROUP BY product_id
HAVING COUNT(*) > 1;
	--No duplicates in product_id--

	--2. Missing values check--
SELECT COUNT(*)
FROM raw.products
WHERE product_id IS NULL;
--No missing values in product_id--
--------------------------------------------------------------------------------------------------------------
	--raw.reviews analysis--
	--1. Duplicates check--
SELECT review_id, COUNT(*) as appearances
FROM raw.reviews
GROUP BY review_id
HAVING COUNT(*) > 1;
	--789 duplicated review_id--
	--Discover the reason for duplication--
SELECT review_id, COUNT(DISTINCT(order_id)) AS count_order_id, COUNT(DISTINCT(review_comment_message)) AS count_review_message
FROM raw.reviews
WHERE review_id IN (
    SELECT review_id
    FROM raw.reviews
    GROUP BY review_id
    HAVING COUNT(*) > 1
)
GROUP BY review_id
ORDER BY count_review_message DESC;
	--Based on this it seems like same review applies to different order_id, likely meaning that within same order multiple items were ordered, but same review.

--------------------------------------------------------------------------------------------------------------
CREATE SCHEMA IF NOT EXISTS analytics;

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

DELETE FROM raw.orders
WHERE TRIM(order_id) = 'order_id';
--the header (first row with columns names) got imported, so need to delete it--

SELECT *
FROM analytics.orders
LIMIT 10;
--------------------------------------------------------------------------------------------------------------
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

DELETE FROM raw.order_items
WHERE TRIM(order_id) = 'order_id';
--the header (first row with columns names) got imported, so need to delete it--

SELECT *
FROM analytics.order_items
LIMIT 10;
--------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE VIEW analytics.customers AS
SELECT
    TRIM(customer_id) AS customer_id,
    NULLIF(TRIM(customer_unique_id), '') AS customer_unique_id,
    NULLIF(TRIM(customer_zip_code_prefix), '') AS zip_code_prefix,
    NULLIF(TRIM(customer_city), '') AS customer_city,
    NULLIF(TRIM(customer_state), '') AS customer_state
FROM raw.customers
WHERE NULLIF(TRIM(customer_id), '') IS NOT NULL;

DELETE FROM raw.customers
WHERE TRIM(customer_id) = 'customer_id';
--the header (first row with columns names) got imported, so need to delete it--

SELECT *
FROM analytics.customers
LIMIT 10;
--------------------------------------------------------------------------------------------------------------
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

DELETE FROM raw.products
WHERE TRIM(product_id) = 'product_id';
--the header (first row with columns names) got imported, so need to delete it--

SELECT *
FROM analytics.products
LIMIT 10;
--------------------------------------------------------------------------------------------------------------
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

DELETE FROM raw.reviews
WHERE TRIM(review_id) = 'review_id';
--the header (first row with columns names) got imported, so need to delete it--

SELECT *
FROM analytics.reviews
LIMIT 10;
--------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE VIEW analytics.category_translation AS
SELECT
    NULLIF(TRIM(product_category_name), '') AS product_category_name,
    NULLIF(TRIM(product_category_name_english), '') AS product_category_name_english
FROM raw.category_translation;

DELETE FROM raw.category_translation
WHERE TRIM(product_category_name) = 'product_category_name';
--the header (first row with columns names) got imported, so need to delete it--

SELECT *
FROM analytics.category_translation;
--------------------------------------------------------------------------------------------------------------
--A. FactOrderItems — one row per order item--
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
	
SELECT *
FROM analytics.fact_order_items
LIMIT 10;
--------------------------------------------------------------------------------------------------------------
--B. FactOrders — one row per order--
CREATE OR REPLACE VIEW analytics.reviews_by_order AS
SELECT
    order_id,
     AVG(review_score)::numeric(3,2) AS average_review_score,
    COUNT(*) AS review_record_count
FROM analytics.reviews
WHERE review_score BETWEEN 1 AND 5
GROUP BY order_id;

SELECT *
FROM analytics.reviews_by_order
LIMIT 5;

SELECT DISTINCT(average_review_score)
FROM analytics.reviews_by_order;
--------------------------------------------------------------------------------------------------------------
--C. Now create the order-level fact view--
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

SELECT COUNT(*)
FROM analytics.fact_orders;
--------------------------------------------------------------------------------------------------------------
--Validate views--
SELECT
    COUNT(*) AS rows,
    COUNT(DISTINCT order_id) AS distinct_orders
FROM analytics.fact_orders;

SELECT
    COUNT(*) AS item_rows,
    COUNT(DISTINCT order_id) AS distinct_orders
FROM analytics.fact_order_items;

SELECT
    SUM(price) AS all_item_value,
    SUM(freight_value) AS all_freight_value
FROM analytics.fact_order_items
WHERE order_status = 'delivered';

--------------------------------------------------------------------------------------------------------------

--Phase 5 — Perform business analysis using SQL--
--1. Monthly sales trend--
SELECT
    DATE_TRUNC(
        'month', order_purchase_timestamp
    )::date AS purchase_month,
    COUNT(DISTINCT order_id) AS delivered_orders,
    SUM(price) AS item_value,
    SUM(freight_value) AS freight_value
FROM analytics.fact_order_items
WHERE order_status = 'delivered'
GROUP BY 1
ORDER BY 1;

--2. Top product categories--
SELECT
    COALESCE(
        product_category_name_english,
        product_category_name,
        'Unknown'
    ) AS category,
    SUM(price) AS item_value,
    COUNT(DISTINCT order_id) AS order_count
FROM analytics.fact_order_items
WHERE order_status = 'delivered'
GROUP BY 1
ORDER BY item_value DESC
LIMIT 10;

--3. Top product categories--
SELECT
    COUNT(*) FILTER (
        WHERE delivered_on_time = FALSE
    ) AS late_orders,

    COUNT(*) FILTER (
        WHERE delivered_on_time IS NOT NULL
    ) AS eligible_orders,

    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE delivered_on_time = FALSE
        )
        / NULLIF(
            COUNT(*) FILTER (
                WHERE delivered_on_time IS NOT NULL
            ),
            0
        ),
        2
    ) AS late_delivery_rate_pct

FROM analytics.fact_orders;

--3. Compare review scores for late and on-time orders--
SELECT
    CASE
        WHEN delivered_on_time = TRUE
            THEN 'On time or early'
        WHEN delivered_on_time = FALSE
            THEN 'Late'
    END AS delivery_group,

    COUNT(*) AS orders,
    ROUND(
        AVG(average_review_score)::numeric,
        2
    ) AS average_review_score

FROM analytics.fact_orders
WHERE delivered_on_time IS NOT NULL
GROUP BY 1
ORDER BY 1;

--------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE VIEW analytics.dim_product AS
SELECT
    p.product_id,
    COALESCE(
        t.product_category_name_english,
        p.product_category_name,
        'Unknown'
    ) AS product_category
FROM analytics.products p
LEFT JOIN analytics.category_translation t
    ON p.product_category_name = t.product_category_name;

	CREATE OR REPLACE VIEW analytics.dim_customer AS
SELECT
    customer_id,
    customer_unique_id,
    customer_city,
    customer_state
FROM analytics.customers;
--------------------------------------------------------------------------------------------------------------
SELECT
    100.0 * COUNT(*) FILTER (
        WHERE delivered_on_time = FALSE
    ) / NULLIF(COUNT(*), 0) AS late_delivery_percentage
FROM analytics.fact_orders
WHERE order_status = 'delivered';