-- name: dim_customers
-- layer: gold
-- description: Customer dimension with purchase behavior
-- depends_on: silver.customers_cleaned, silver.orders_cleaned

CREATE OR REPLACE TABLE gold.dim_customers AS
WITH customer_metrics AS (
    SELECT 
        c.customer_id,
        COUNT(o.order_id) AS total_orders,
        COALESCE(SUM(o.total_amount), 0) AS total_spent,
        COALESCE(AVG(o.total_amount), 0) AS avg_order_value,
        MIN(o.order_date) AS first_order_date,
        MAX(o.order_date) AS last_order_date
    FROM silver.customers_cleaned c
    LEFT JOIN silver.orders_cleaned o ON c.customer_id = o.customer_id
    GROUP BY c.customer_id
)
SELECT 
    c.customer_id,
    c.first_name,
    c.last_name,
    c.full_name,
    c.email,
    c.city,
    c.state,
    c.signup_date,
    c.customer_type,
    -- Purchase metrics
    m.total_orders,
    m.total_spent,
    m.avg_order_value,
    m.first_order_date,
    m.last_order_date,
    -- Customer segmentation
    CASE 
        WHEN m.total_spent >= 2000 THEN 'VIP'
        WHEN m.total_spent >= 1000 THEN 'PREMIUM'
        WHEN m.total_spent >= 200 THEN 'STANDARD'
        WHEN m.total_orders > 0 THEN 'BASIC'
        ELSE 'PROSPECT'
    END AS value_segment,
    CASE 
        WHEN m.last_order_date IS NULL THEN 'NEVER_PURCHASED'
        WHEN m.last_order_date >= CURRENT_DATE - INTERVAL '30 days' THEN 'ACTIVE'
        WHEN m.last_order_date >= CURRENT_DATE - INTERVAL '90 days' THEN 'AT_RISK'
        ELSE 'INACTIVE'
    END AS lifecycle_stage
FROM silver.customers_cleaned c
LEFT JOIN customer_metrics m ON c.customer_id = m.customer_id;
-- This query creates a customer dimension table that includes customer details,
-- purchase behavior metrics, and customer segmentation.    