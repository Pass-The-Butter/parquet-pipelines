-- name: product_interactions
-- layer: silver
-- description: Product purchase patterns and customer interactions
-- depends_on: bronze.order_items, bronze.orders, bronze.products

CREATE OR REPLACE TABLE silver.product_interactions AS
SELECT 
    o.customer_id,  -- Get customer_id from orders table
    oi.product_id,
    p.product_name,
    p.category,
    p.price,
    COUNT(*) as purchase_count,
    SUM(oi.quantity) as total_quantity,
    SUM(oi.line_total) as total_spent_on_product,
    AVG(oi.unit_price) as avg_purchase_price,
    MIN(o.order_date) as first_purchase_date,
    MAX(o.order_date) as last_purchase_date,
    -- Loyalty to this product
    COUNT(*) / COUNT(DISTINCT oi.order_id) as product_loyalty_score,
    -- Purchase frequency
    COUNT(DISTINCT o.order_date) as purchase_sessions
FROM bronze.order_items oi
INNER JOIN bronze.orders o ON oi.order_id = o.order_id  -- Join to get customer_id
INNER JOIN bronze.products p ON oi.product_id = p.product_id
GROUP BY o.customer_id, oi.product_id, p.product_name, p.category, p.price;
-- This query aggregates product interactions by customer, providing insights into purchase patterns.
-- It calculates total purchases, quantities, spending, and loyalty scores for each product.        