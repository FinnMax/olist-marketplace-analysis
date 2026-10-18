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
SELECT COUNT(DISTINCT(review_id))
FROM raw.reviews
LIMIT 2;

SELECT
    review_id,
    COUNT(*) AS number_of_records,
    COUNT(DISTINCT order_id) AS number_of_unique_orders,
    COUNT(DISTINCT review_score) AS number_of_unique_scores
FROM raw.reviews
GROUP BY review_id
HAVING COUNT(*) > 1
ORDER BY number_of_records DESC;
--There are review_id duplicates but the associated order_id are different, even though the review score is the same
--number_of_unique_scores_per_review_group = 1

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
--Some orders in the reviews table are associated with two or three review records. 
--The number of distinct review IDs matches the number of review records for these orders, 
--suggesting that the repeated order IDs are not caused by repeated review IDs within those orders. 
--However, the number of distinct review scores and messages varies. 
--This indicates that some reviews share scores or contain missing or repeated message values. 
--Further investigation of the review content and timestamps is required to determine whether 
--these records represent legitimate multiple review entries or data-quality inconsistencies.
--------------------------------------------------------------------------------------------------------------
--order_id(payments table)
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