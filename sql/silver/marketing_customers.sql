-- name: marketing_customers
-- layer: silver
-- description: Customer data optimized for marketing analysis with behavioral metrics
-- depends_on: bronze.customers, bronze.orders, bronze.customer_loyalty

CREATE OR REPLACE TABLE silver.marketing_customers AS
WITH customer_behavior AS (
    SELECT 
        c.customer_id,
        c.first_name,
        c.last_name,
        c.email,
        c.city,
        c.state,
        c.date_of_birth,
        c.created_date as signup_date,
        c.customer_type,
        -- Order behavior
        COUNT(o.order_id) as total_orders,
        COALESCE(SUM(o.total_amount), 0) as total_spent,
        COALESCE(AVG(o.total_amount), 0) as avg_order_value,
        MIN(o.order_date) as first_order_date,
        MAX(o.order_date) as last_order_date,
        -- Time-based metrics
        DATE_DIFF('day', MAX(o.order_date), CURRENT_DATE) as days_since_last_order,
        DATE_DIFF('day', MIN(o.order_date), MAX(o.order_date)) as customer_lifespan_days,
        COUNT(DISTINCT DATE_TRUNC('month', o.order_date)) as active_months,
        -- Seasonal behavior
        SUM(CASE WHEN EXTRACT(month FROM o.order_date) IN (11, 12) THEN o.total_amount ELSE 0 END) as holiday_spending,
        SUM(CASE WHEN EXTRACT(dayofweek FROM o.order_date) IN (1, 7) THEN o.total_amount ELSE 0 END) as weekend_spending,
        -- Payment preferences
        MODE() WITHIN GROUP (ORDER BY o.payment_method) as preferred_payment_method
    FROM bronze.customers c
    LEFT JOIN bronze.orders o ON c.customer_id = o.customer_id
    WHERE c.active = 1
    GROUP BY c.customer_id, c.first_name, c.last_name, c.email, c.city, c.state, 
             c.date_of_birth, c.created_date, c.customer_type
)
SELECT 
    *,
    -- Calculate customer age
    CASE 
        WHEN date_of_birth IS NOT NULL THEN 
            DATE_DIFF('year', date_of_birth, CURRENT_DATE)
        ELSE NULL
    END AS age,
    -- Age groups for marketing
    CASE 
        WHEN date_of_birth IS NULL THEN 'Unknown'
        WHEN DATE_DIFF('year', date_of_birth, CURRENT_DATE) < 25 THEN 'Gen Z'
        WHEN DATE_DIFF('year', date_of_birth, CURRENT_DATE) < 40 THEN 'Millennial'
        WHEN DATE_DIFF('year', date_of_birth, CURRENT_DATE) < 55 THEN 'Gen X'
        ELSE 'Boomer+'
    END AS generation,
    -- Purchase frequency
    CASE 
        WHEN total_orders = 0 THEN 0
        WHEN customer_lifespan_days = 0 THEN total_orders
        ELSE ROUND(total_orders / (customer_lifespan_days / 30.0), 2)
    END AS orders_per_month,
    -- Holiday shopper flag
    CASE 
        WHEN total_spent > 0 AND (holiday_spending / total_spent) > 0.3 THEN true
        ELSE false
    END AS is_holiday_shopper,
    -- Weekend shopper flag
    CASE 
        WHEN total_spent > 0 AND (weekend_spending / total_spent) > 0.5 THEN true
        ELSE false
    END AS is_weekend_shopper
FROM customer_behavior;
-- This query creates a marketing-focused customer table that includes detailed behavioral metrics.
-- It aggregates customer data from orders and calculates various metrics such as total spending,
-- average order value, and purchase frequency. It also segments customers by age group and
-- identifies holiday and weekend shoppers based on their spending patterns.
-- The table is designed to support targeted marketing campaigns and customer segmentation analysis.
-- The resulting table can be used for advanced marketing analytics, customer segmentation,