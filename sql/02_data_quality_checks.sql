--------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------
--Check duplicates in key columns--
SELECT
    'orders' AS table_name,
    order_id AS id_value,
    COUNT(*) AS occurrences
FROM raw.orders
GROUP BY order_id
HAVING COUNT(*) > 1

UNION ALL

SELECT
    'order_items',
    order_id,
    COUNT(*)
FROM raw.order_items
GROUP BY order_id
HAVING COUNT(*) > 1

UNION ALL

SELECT
    'customers',
    customer_id,
    COUNT(*)
FROM raw.customers
GROUP BY customer_id
HAVING COUNT(*) > 1

UNION ALL

SELECT
    'customers',
    customer_unique_id,
    COUNT(*)
FROM raw.customers
GROUP BY customer_unique_id
HAVING COUNT(*) > 1

UNION ALL

SELECT
    'products',
    product_id,
    COUNT(*)
FROM raw.products
GROUP BY product_id
HAVING COUNT(*) > 1

UNION ALL

SELECT
    'reviews',
    review_id,
    COUNT(*)
FROM raw.reviews
GROUP BY review_id
HAVING COUNT(*) > 1

UNION ALL

SELECT
    'category_translation',
    product_category_name,
    COUNT(*)
FROM raw.category_translation
GROUP BY product_category_name
HAVING COUNT(*) > 1

UNION ALL

SELECT
    'order_payments',
    order_id,
    COUNT(*)
FROM raw.order_payments
GROUP BY order_id
HAVING COUNT(*) > 1

ORDER BY table_name, occurrences ASC;
--Duplicates have been detected in the 
--order_id(order_items table), 
--customer_unique_id(customers table), 
--review_id(reviews table)
--order_id(payments table)
--------------------------------------------------------------------------------------------------------------
--Deeper duplicates exploration--
--------------------------------------------------------------------------------------------------------------
--order_id(order_items table)
SELECT
    order_id,
    order_item_id,
    COUNT(*) AS occurrences
FROM raw.order_items
GROUP BY
    order_id,
    order_item_id
HAVING COUNT(*) > 1
ORDER BY occurrences DESC;
--No composite duplicates detected--

WITH duplicated_order_id AS (
    SELECT
        order_id,
        COUNT(order_item_id) AS number_of_items_per_order,
        COUNT(*) AS appearance_of_order
    FROM raw.order_items
    GROUP BY order_id
    HAVING COUNT(*) > 1
)
SELECT *
FROM duplicated_order_id
WHERE number_of_items_per_order <> appearance_of_order;

--No orders like this are detected, suggesting that the duplication of the order_id is due to the several items per order_id--
-- Check for duplicate order-item combinations
SELECT
    order_id,
    order_item_id,
    COUNT(*) AS occurrences
FROM raw.order_items
GROUP BY
    order_id,
    order_item_id
HAVING COUNT(*) > 1
ORDER BY occurrences DESC;
--The repeated order_id values in raw.order_items are consistent with the table's one-to-many structure, 
--where a single order can contain multiple items. No duplicate (order_id, order_item_id) combinations were detected, 
--so these repeated order IDs are not evidence of duplicate order-item records.
--------------------------------------------------------------------------------------------------------------
--customer_unique_id(customers table)
SELECT *
FROM raw.customers
WHERE customer_unique_id IN
	(SELECT customer_unique_id
	FROM raw.customers
	GROUP BY customer_unique_id
	HAVING COUNT(*) > 1)
ORDER BY customer_unique_id;
--the repeated customer_unique_id values suggest that the same underlying customer has multiple records

--Check whether these records are associated with different orders
SELECT
    c.customer_unique_id,
    c.customer_id,
    o.order_id,
    o.order_status,
    o.order_purchase_timestamp
FROM raw.customers AS c
LEFT JOIN raw.orders AS o
    ON c.customer_id = o.customer_id
WHERE c.customer_unique_id =
    '00172711b30d52eea8b313a7f2cced02'
ORDER BY o.order_purchase_timestamp;

--Quantify this across all customers--
SELECT
    c.customer_unique_id,
    COUNT(DISTINCT c.customer_id) AS customer_records,
    COUNT(DISTINCT o.order_id) AS total_orders
FROM raw.customers AS c
LEFT JOIN raw.orders AS o
    ON c.customer_id = o.customer_id
GROUP BY c.customer_unique_id
HAVING COUNT(DISTINCT c.customer_id) > 1
ORDER BY total_orders DESC;
--The repeated customer_unique_id values are consistent with the Olist dataset's structure, 
--in which one underlying customer can be associated with multiple customer records and orders. 
--The investigation of the example customer confirmed two distinct orders with different statuses. 
--Therefore, repeated customer_unique_id values should not automatically be classified as duplicate records or removed.
--------------------------------------------------------------------------------------------------------------
--review_id(reviews table)
SELECT *
FROM raw.reviews
WHERE review_id IN (
    SELECT review_id
    FROM raw.reviews
    GROUP BY review_id
    HAVING COUNT(*) > 1
)
ORDER BY review_id, order_id;

SELECT
    review_id,
    COUNT(*) AS number_of_records,
    COUNT(DISTINCT order_id) AS number_of_unique_orders,
    COUNT(DISTINCT review_score) AS number_of_unique_scores,
    COUNT(DISTINCT review_creation_date) AS number_of_unique_creation_dates,
    COUNT(DISTINCT review_comment_message) AS number_of_unique_messages,
    COUNT(DISTINCT review_answer_timestamp) AS number_of_unique_answer_timestamps
FROM raw.reviews
GROUP BY review_id
HAVING COUNT(*) > 1
ORDER BY number_of_records DESC;

SELECT
    COUNT(*) AS total_duplicate_records,
    COUNT(DISTINCT review_id) AS duplicate_review_ids
FROM raw.reviews
WHERE review_id IN (
    SELECT review_id
    FROM raw.reviews
    GROUP BY review_id
    HAVING COUNT(*) > 1
);

--During data quality checks on raw.reviews, I identified 1,603 records associated with 789 duplicated review_id values. 
--After comparing the records, the repeated entries appeared to contain identical review information, indicating duplicate review records.

SELECT *
FROM raw.reviews
WHERE order_id IN
	(SELECT order_id
	FROM raw.reviews
	GROUP BY order_id
	HAVING COUNT(*) > 1)
ORDER BY order_id;
--There appears to be several duplicated order_id with several different review_id,
--some of there reviews have different review_scores and different messages as well--

SELECT
    order_id,
    COUNT(*) AS number_of_reviews,
    COUNT(DISTINCT review_id) AS unique_review_ids,
    COUNT(DISTINCT review_score) AS unique_review_scores,
    COUNT(DISTINCT review_comment_message)
        AS unique_review_messages
FROM raw.reviews
GROUP BY order_id
HAVING COUNT(*) > 1
ORDER BY number_of_reviews DESC;
--The investigation identified multiple records associated with the same order_id. 
--Some orders have two or three review records, each associated with a different review_id.
--The results show that the number of distinct review_id values matches the total number of records for these orders. 
--This suggests that the repeated order_id values are not caused by repeated review IDs within the same order.
--However, some records have different review scores and review messages, indicating that the records are not necessarily exact duplicates. 
--Some message values may also be missing or repeated.
--------------------------------------------------------------------------------------------------------------
--order_id(payments table)
SELECT
    order_id,
    payment_sequential,
    COUNT(*) AS occurrences
FROM raw.order_payments
GROUP BY
    order_id,
    payment_sequential
HAVING COUNT(*) > 1
ORDER BY occurrences DESC;
--No composite duplicates detected

SELECT *
FROM raw.order_payments
WHERE order_id IN
	(SELECT order_id
	FROM raw.order_payments
	GROUP BY order_id
	HAVING COUNT(*) > 1)
ORDER BY order_id;

SELECT order_id,  COUNT(payment_sequential)
FROM raw.order_payments
GROUP BY order_id
HAVING COUNT(*) > 1
ORDER BY COUNT(payment_sequential) ASC;

--THIS SEEMS LIKE A LEGIT NON DUPLICATES, THE REASON FOR DUPLICATES SEEMS TO BE SEVERAL PAYMENTS BECAUSE 
--COUNT(payment_sequential) > 1 FOR ALL THE GROUPED ORDER_ID
--------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------
--Check missing values in key columns--
--------------------------------------------------------------------------------------------------------------
--category translation--
SELECT *
FROM raw.category_translation
WHERE NULLIF(TRIM(product_category_name), '') IS NULL
OR NULLIF(TRIM(product_category_name_english), '') IS NULL;
--No missing values--
--------------------------------------------------------------------------------------------------------------
--customers--
SELECT *
FROM raw.customers
WHERE NULLIF(TRIM(customer_id), '') IS NULL
OR NULLIF(TRIM(customer_unique_id), '') IS NULL
OR NULLIF(TRIM(customer_city), '') IS NULL
OR NULLIF(TRIM(customer_state), '') IS NULL;
--No missing values--
--------------------------------------------------------------------------------------------------------------
--order_items--
SELECT *
FROM raw.order_items
WHERE NULLIF(TRIM(order_id), '') IS NULL
OR NULLIF(TRIM(order_item_id), '') IS NULL
OR NULLIF(TRIM(product_id), '') IS NULL
OR NULLIF(TRIM(seller_id), '') IS NULL
OR NULLIF(TRIM(price), '') IS NULL
OR NULLIF(TRIM(freight_value), '') IS NULL;
--No missing values--
--------------------------------------------------------------------------------------------------------------
--order_payments--
SELECT *
FROM raw.order_payments
WHERE NULLIF(TRIM(order_id), '') IS NULL
OR payment_sequential IS NULL
OR NULLIF(TRIM(payment_type), '') IS NULL
OR payment_installments IS NULL
OR payment_value IS NULL;
--No missing values--
--------------------------------------------------------------------------------------------------------------
--orders--
SELECT *
FROM raw.orders
WHERE NULLIF(TRIM(order_id), '') IS NULL
OR NULLIF(TRIM(customer_id), '') IS NULL
OR NULLIF(TRIM(order_status), '') IS NULL
OR NULLIF(TRIM(order_purchase_timestamp), '') IS NULL
OR NULLIF(TRIM(order_delivered_customer_date), '') IS NULL
OR NULLIF(TRIM(order_estimated_delivery_date), '') IS NULL;
--2956 orders with the missing order_delivered_customer_date were detected--
SELECT order_status, COUNT(*)
FROM raw.orders
WHERE NULLIF(TRIM(order_delivered_customer_date), '') IS NULL
GROUP BY order_status;
--"approved"	2--
--"canceled"	619--
--"created"		5--
--"delivered"	8--
--"invoiced"	314--
--"processing"	301--
--"shipped"		1107--
--"unavailable"	609--

SELECT *
FROM raw.orders
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NULL;

SELECT COUNT(*)
FROM raw.orders
WHERE order_status = 'delivered';
--Eight orders marked as delivered have missing order_delivered_customer_date values. This is inconsistent with the expected meaning of the order status, as delivered orders would normally be expected to have a recorded customer delivery timestamp.

--Compared with the more than 96,000+ delivered orders in the dataset, these eight records represent a negligible proportion (less than approximately 0.009%).
--------------------------------------------------------------------------------------------------------------
--products--
SELECT *
FROM raw.products
WHERE NULLIF(TRIM(product_id), '') IS NULL
OR NULLIF(TRIM(product_category_name), '') IS NULL;
--There are 610 products with missing product_category_name--

SELECT 
	o.order_id,
	o.order_item_id,
	o.product_id,
	p.product_category_name
FROM raw.order_items AS o
INNER JOIN raw.products AS p
ON o.product_id = p.product_id
WHERE product_category_name IS NULL
ORDER BY order_id;
-- total of 610 products were identified with missing product category information in raw.products. A join between raw.order_items and raw.products was used to identify order items associated with these products.

--These missing categories may affect category-level sales analysis, product segmentation, and reporting. However, the absence of category information does not necessarily indicate that the products themselves are invalid.

--Decision: Retain these products in the dataset rather than removing them. Preserve the missing category values as NULL or assign an explicit label such as Unknown in the reporting layer, depending on the analysis requirements.
--------------------------------------------------------------------------------------------------------------
--reviews--
SELECT *
FROM raw.reviews
WHERE NULLIF(TRIM(review_id), '') IS NULL
OR NULLIF(TRIM(order_id), '') IS NULL
OR NULLIF(TRIM(review_score), '') IS NULL;
--No missing values--
--------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------