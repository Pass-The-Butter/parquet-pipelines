-- name: product_affinity_analysis
-- layer: gold
-- description: Products frequently bought together - market basket analysis
-- depends_on: bronze.order_items, bronze.products

CREATE OR REPLACE TABLE gold.product_affinity_analysis AS
WITH product_pairs AS (
    SELECT 
        oi1.product_id as product_a_id,
        p1.product_name as product_a_name,
        p1.category as product_a_category,
        oi2.product_id as product_b_id,
        p2.product_name as product_b_name,
        p2.category as product_b_category,
        COUNT(DISTINCT oi1.order_id) as times_bought_together,
        -- Count unique customers who bought both
        COUNT(DISTINCT o.customer_id) as customers_bought_both
    FROM bronze.order_items oi1
    INNER JOIN bronze.order_items oi2 ON oi1.order_id = oi2.order_id 
        AND oi1.product_id < oi2.product_id  -- Avoid duplicates
    INNER JOIN bronze.orders o ON oi1.order_id = o.order_id  -- Get customer info
    INNER JOIN bronze.products p1 ON oi1.product_id = p1.product_id
    INNER JOIN bronze.products p2 ON oi2.product_id = p2.product_id
    GROUP BY oi1.product_id, p1.product_name, p1.category,
             oi2.product_id, p2.product_name, p2.category
    HAVING COUNT(DISTINCT oi1.order_id) >= 2  -- At least bought together twice
),
product_totals AS (
    SELECT 
        product_id,
        COUNT(DISTINCT order_id) as total_orders
    FROM bronze.order_items
    GROUP BY product_id
)
SELECT 
    pp.*,
    pta.total_orders as product_a_total_orders,
    ptb.total_orders as product_b_total_orders,
    -- Confidence (A -> B)
    ROUND(pp.times_bought_together * 100.0 / pta.total_orders, 2) as confidence_a_to_b,
    -- Confidence (B -> A)  
    ROUND(pp.times_bought_together * 100.0 / ptb.total_orders, 2) as confidence_b_to_a,
    -- Marketing recommendation
    CASE 
        WHEN pp.times_bought_together >= 10 THEN 'Strong bundle opportunity'
        WHEN pp.times_bought_together >= 5 THEN 'Cross-sell opportunity'
        WHEN pp.times_bought_together >= 3 THEN 'Monitor for trends'
        ELSE 'Weak correlation'
    END as marketing_opportunity
FROM product_pairs pp
LEFT JOIN product_totals pta ON pp.product_a_id = pta.product_id
LEFT JOIN product_totals ptb ON pp.product_b_id = ptb.product_id
ORDER BY times_bought_together DESC, customers_bought_both DESC;
-- This query performs market basket analysis to find products frequently bought together.
-- It calculates confidence scores and provides marketing recommendations based on purchase patterns.   