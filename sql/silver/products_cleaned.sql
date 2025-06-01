-- name: products_cleaned
-- layer: silver
-- description: Clean product data with pricing analysis
-- depends_on: bronze.products

CREATE OR REPLACE TABLE silver.products_cleaned AS
SELECT 
    product_id,
    TRIM(product_name) AS product_name,
    TRIM(UPPER(category)) AS category,
    price,
    cost,
    ROUND(price - cost, 2) AS margin_amount,
    CASE 
        WHEN price > 0 THEN ROUND((price - cost) / price * 100, 2)
        ELSE 0
    END AS margin_percent,
    TRIM(sku) AS sku,
    TRIM(description) AS description,
    weight_lbs,
    TRIM(supplier) AS supplier,
    created_date,
    updated_date,
    active,
    stock_quantity,
    -- Price tiers for analysis
    CASE 
        WHEN price >= 100 THEN 'HIGH'
        WHEN price >= 50 THEN 'MEDIUM'
        WHEN price >= 20 THEN 'LOW'
        ELSE 'BUDGET'
    END AS price_tier,
    -- Margin analysis
    CASE 
        WHEN price > 0 AND (price - cost) / price >= 0.5 THEN 'HIGH_MARGIN'
        WHEN price > 0 AND (price - cost) / price >= 0.3 THEN 'MEDIUM_MARGIN'
        WHEN price > 0 AND (price - cost) / price >= 0.1 THEN 'LOW_MARGIN'
        ELSE 'POOR_MARGIN'
    END AS margin_category
FROM bronze.products
WHERE product_id IS NOT NULL
    AND product_name IS NOT NULL
    AND price > 0
    AND active = 1;
-- This query cleans the product data, calculates margin amounts and percentages,
-- categorizes products into price tiers, and classifies margin performance.
-- It ensures that only active products with valid IDs and names are included.
-- The margin analysis helps in identifying products with high, medium, low, or poor margins.
-- This table can be used for further analysis, reporting, or as a source for downstream applications.
-- The cleaned data is ready for use in analytics, reporting, or further processing.





