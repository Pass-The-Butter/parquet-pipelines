-- name: fact_sales
-- layer: gold
-- description: Sales fact table with all business metrics
-- depends_on: silver.order_items, silver.orders_cleaned, gold.dim_customers

CREATE OR REPLACE TABLE gold.fact_sales AS
SELECT 
    -- Primary keys
    oi.order_item_id AS sales_line_key,
    oi.order_id,
    oi.product_id,
    o.customer_id,
    o.order_date,
    
    -- Measures
    oi.quantity,
    oi.unit_price,
    oi.line_total,
    
    -- Order context
    o.subtotal AS order_subtotal,
    o.tax_amount AS order_tax,
    o.shipping_cost AS order_shipping,
    o.total_amount AS order_total,
    
    -- Time dimensions
    o.order_year,
    o.order_month,
    o.order_quarter,
    o.order_day_of_week,
    o.order_month_start,
    o.weekend_flag,
    
    -- Customer attributes (denormalized for performance)
    c.value_segment AS customer_value_segment,
    c.lifecycle_stage AS customer_lifecycle_stage,
    c.state AS customer_state,
    
    -- Order attributes
    o.order_value_tier,
    o.status AS order_status,
    o.payment_method

FROM bronze.order_items oi
INNER JOIN silver.orders_cleaned o ON oi.order_id = o.order_id
LEFT JOIN gold.dim_customers c ON o.customer_id = c.customer_id
WHERE oi.quantity > 0 AND oi.unit_price > 0;
-- This query creates a sales fact table that combines order items with order and customer data.
-- It includes all relevant business metrics such as quantities, prices, order totals,
-- and customer segments. The table is designed for efficient querying and analysis of sales performance.
-- The fact table is ready for use in analytics, reporting, or further processing.
-- It allows for detailed analysis of sales performance, customer behavior, and order trends.
-- The denormalized structure improves query performance for reporting and analytics.