--------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------
--Analytics schema creation--
CREATE SCHEMA IF NOT EXISTS analytics;
--------------------------------------------------------------------------------------------------------------
--analytics.orders creation--
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
--analytics.orders creation--