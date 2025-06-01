-- name: orders_cleaned
-- layer: silver
-- description: Clean order data with time dimensions
-- depends_on: bronze.orders

CREATE OR REPLACE TABLE silver.orders_cleaned AS
SELECT 
    order_id,
    customer_id,
    order_date,
    ship_date,
    delivery_date,
    TRIM(UPPER(status)) AS status,
    TRIM(payment_method) AS payment_method,
    subtotal,
    tax_amount,
    shipping_cost,
    total_amount,
    created_date,
    -- Time dimensions
    EXTRACT(year FROM order_date) AS order_year,
    EXTRACT(month FROM order_date) AS order_month,
    EXTRACT(quarter FROM order_date) AS order_quarter,
    EXTRACT(dayofweek FROM order_date) AS order_day_of_week,
    DATE_TRUNC('month', order_date) AS order_month_start,
    DATE_TRUNC('quarter', order_date) AS order_quarter_start,
    -- Business logic
    CASE 
        WHEN total_amount >= 500 THEN 'HIGH_VALUE'
        WHEN total_amount >= 100 THEN 'MEDIUM_VALUE'
        WHEN total_amount >= 25 THEN 'LOW_VALUE'
        ELSE 'MINIMAL_VALUE'
    END AS order_value_tier,
    CASE 
        WHEN EXTRACT(dayofweek FROM order_date) IN (1, 7) THEN 'WEEKEND'
        ELSE 'WEEKDAY'
    END AS weekend_flag
FROM bronze.orders
WHERE order_id IS NOT NULL
    AND customer_id IS NOT NULL
    AND order_date IS NOT NULL
    AND total_amount > 0;
-- This query cleans the order data, extracts time dimensions, and categorizes orders
-- into value tiers based on total amount.
-- It ensures that only valid orders with non-null IDs, customer IDs, and order dates are included.
-- The time dimensions allow for detailed analysis of order trends over time.
-- The order value tier helps in identifying high, medium, low, and minimal value orders.