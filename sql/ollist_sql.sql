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
