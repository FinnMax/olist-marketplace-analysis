--------------------------------------------------------------------------------------------------------------
-- СКРИПТ ПРОВЕРКИ КАЧЕСТВА ДАННЫХ (DATA QUALITY CHECKS)
-- Цель: выявить дубликаты, пропуски и аномалии в сырых данных перед построением аналитики.
--------------------------------------------------------------------------------------------------------------
-- 1. ПОИСК ДУБЛИКАТОВ В КЛЮЧЕВЫХ КОЛОНКАХ
--------------------------------------------------------------------------------------------------------------
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

-- Обнаружены дубликаты в:
-- order_id (таблица order_items)
-- customer_unique_id (таблица customers)
-- review_id (таблица reviews)
-- order_id (таблица order_payments)

--------------------------------------------------------------------------------------------------------------
-- 2. ДЕТАЛЬНЫЙ АНАЛИЗ ОБНАРУЖЕННЫХ ДУБЛИКАТОВ
--------------------------------------------------------------------------------------------------------------
-- 2.1. Анализ order_id в таблице order_items
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
-- Составных дубликатов (order_id + order_item_id) не обнаружено.

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
-- Заказов с несовпадением количества не обнаружено. 
-- Вывод: дублирование order_id обусловлено структурой "один-ко-многим" (несколько товаров в одном заказе).

-- Повторная проверка на дубликаты комбинаций order_id + order_item_id
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
-- Повторяющиеся order_id в raw.order_items соответствуют структуре таблицы, где в одном заказе может быть несколько товаров.
-- Дубликатов комбинаций (order_id, order_item_id) нет, поэтому эти записи не являются дублями.
--------------------------------------------------------------------------------------------------------------
-- 2.2. Анализ customer_unique_id в таблице customers
SELECT *
FROM raw.customers
WHERE customer_unique_id IN
	(SELECT customer_unique_id
	FROM raw.customers
	GROUP BY customer_unique_id
	HAVING COUNT(*) > 1)
ORDER BY customer_unique_id;
-- Повторяющиеся customer_unique_id указывают на то, что один и тот же клиент может иметь несколько записей.

-- Проверка, связаны ли эти записи с разными заказами
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

-- Количественная оценка по всем клиентам
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
-- Повторяющиеся customer_unique_id соответствуют структуре датасета Olist, 
-- где один клиент может быть связан с несколькими customer_id и заказами.
-- Проверка примера подтвердила наличие двух разных заказов.
-- Вывод: повторяющиеся customer_unique_id не являются дублями и не подлежат удалению.
--------------------------------------------------------------------------------------------------------------
-- 2.3. Анализ review_id в таблице reviews
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

-- В ходе проверки качества данных в raw.reviews обнаружено 1 603 записи с 789 дублирующимися значениями review_id.
-- Сравнение записей показало, что повторяющиеся строки содержат идентичную информацию об отзыве,
-- что указывает на полные дубликаты.

SELECT *
FROM raw.reviews
WHERE order_id IN
	(SELECT order_id
	FROM raw.reviews
	GROUP BY order_id
	HAVING COUNT(*) > 1)
ORDER BY order_id;
-- Обнаружено несколько дублирующихся order_id с разными review_id.
-- Некоторые из этих отзывов имеют разные оценки и тексты сообщений.

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
-- Обнаружено несколько записей с одинаковым order_id. У некоторых заказов есть 2 или 3 отзыва, 
-- каждый с уникальным review_id.
-- Количество уникальных review_id совпадает с общим числом записей для этих заказов.
-- Это говорит о том, что повторяющиеся order_id не вызваны дублированием ID отзывов внутри одного заказа.
-- Однако некоторые записи имеют разные оценки и сообщения, что означает, что они не являются точными дублями.
--------------------------------------------------------------------------------------------------------------
-- 2.4. Анализ order_id в таблице order_payments
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
-- Составных дубликатов (order_id + payment_sequential) не обнаружено.

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

-- Вывод: эти записи не являются дублями. Причина в том, что COUNT(payment_sequential) > 1 для всех сгруппированных order_id.
-- Один заказ может быть оплачен несколькими транзакциями (например, часть на карту, часть ваучером).
--------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------
-- 3. ПРОВЕРКА ПРОПУЩЕННЫХ ЗНАЧЕНИЙ (NULL / ПУСТЫЕ СТРОКИ)
--------------------------------------------------------------------------------------------------------------
-- 3.1. Проверка category_translation
SELECT *
FROM raw.category_translation
WHERE NULLIF(TRIM(product_category_name), '') IS NULL
OR NULLIF(TRIM(product_category_name_english), '') IS NULL;
-- Пропусков не обнаружено.
--------------------------------------------------------------------------------------------------------------
-- 3.2. Проверка customers
SELECT *
FROM raw.customers
WHERE NULLIF(TRIM(customer_id), '') IS NULL
OR NULLIF(TRIM(customer_unique_id), '') IS NULL
OR NULLIF(TRIM(customer_city), '') IS NULL
OR NULLIF(TRIM(customer_state), '') IS NULL;
-- Пропусков не обнаружено.
--------------------------------------------------------------------------------------------------------------
-- 3.3. Проверка order_items
SELECT *
FROM raw.order_items
WHERE NULLIF(TRIM(order_id), '') IS NULL
OR NULLIF(TRIM(order_item_id), '') IS NULL
OR NULLIF(TRIM(product_id), '') IS NULL
OR NULLIF(TRIM(seller_id), '') IS NULL
OR NULLIF(TRIM(price), '') IS NULL
OR NULLIF(TRIM(freight_value), '') IS NULL;
-- Пропусков не обнаружено.
--------------------------------------------------------------------------------------------------------------
-- 3.4. Проверка order_payments
SELECT *
FROM raw.order_payments
WHERE NULLIF(TRIM(order_id), '') IS NULL
OR payment_sequential IS NULL
OR NULLIF(TRIM(payment_type), '') IS NULL
OR payment_installments IS NULL
OR payment_value IS NULL;
-- Пропусков не обнаружено.
--------------------------------------------------------------------------------------------------------------
-- 3.5. Проверка orders
SELECT *
FROM raw.orders
WHERE NULLIF(TRIM(order_id), '') IS NULL
OR NULLIF(TRIM(customer_id), '') IS NULL
OR NULLIF(TRIM(order_status), '') IS NULL
OR NULLIF(TRIM(order_purchase_timestamp), '') IS NULL
OR NULLIF(TRIM(order_delivered_customer_date), '') IS NULL
OR NULLIF(TRIM(order_estimated_delivery_date), '') IS NULL;
-- Обнаружено 2 956 заказов с пропущенной датой доставки клиенту (order_delivered_customer_date).

SELECT order_status, COUNT(*)
FROM raw.orders
WHERE NULLIF(TRIM(order_delivered_customer_date), '') IS NULL
GROUP BY order_status;
-- Статусы: approved (2), canceled (619), created (5), delivered (8), invoiced (314), 
-- processing (301), shipped (1107), unavailable (609).

SELECT *
FROM raw.orders
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NULL;

SELECT COUNT(*)
FROM raw.orders
WHERE order_status = 'delivered';
-- Восемь заказов со статусом "delivered" имеют пропущенную дату доставки. 
-- Это несоответствие: доставленные заказы должны иметь зафиксированную дату вручения.
-- По сравнению с более чем 96 000+ доставленных заказов в датасете, эти 8 записей 
-- составляют ничтожную долю (менее ~0.009%).
--------------------------------------------------------------------------------------------------------------
-- 3.6. Проверка products
SELECT *
FROM raw.products
WHERE NULLIF(TRIM(product_id), '') IS NULL
OR NULLIF(TRIM(product_category_name), '') IS NULL;
-- Обнаружено 610 товаров с пропущенной категорией (product_category_name).

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
-- Всего 610 товаров без категории. Джойн показал, что они встречаются в заказах.
-- Отсутствие категории может повлиять на анализ продаж по категориям и сегментацию.
-- При этом отсутствие категории не означает, что товар невалиден.
-- Решение: оставить эти товары в датасете. Пропуски заменить на NULL или метку "Unknown" 
-- на слое отчетности (в зависимости от требований аналитики).
--------------------------------------------------------------------------------------------------------------
-- 3.7. Проверка reviews
SELECT *
FROM raw.reviews
WHERE NULLIF(TRIM(review_id), '') IS NULL
OR NULLIF(TRIM(order_id), '') IS NULL
OR NULLIF(TRIM(review_score), '') IS NULL;
-- Пропусков не обнаружено.
--------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------