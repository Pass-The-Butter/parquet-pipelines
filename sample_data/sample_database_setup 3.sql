
-- ============================================================================
-- 10. CREATE VIEWS FOR COMMON QUERIES
-- ============================================================================
-- ============================================================================
-- Sample Database Setup for Parquet Pipelines Testing
-- Database: SampleRetailDB
-- Description: E-commerce/retail sample data with customers, products, orders
-- ============================================================================

    -- Switch to the new database
    USE SampleRetailDB;
GO

-- Customer summary view
CREATE VIEW dbo.vw_customer_summary AS
SELECT 
    c.customer_id,
    c.first_name,
    c.last_name,
    c.email,
    c.city,
    c.state,
    c.customer_type,
    c.created_date as signup_date,
    COUNT(o.order_id) as total_orders,
    ISNULL(SUM(o.total_amount), 0) as lifetime_value,
    MAX(o.order_date) as last_order_date,
    cl.points_balance,
    cl.tier_level
FROM dbo.customers c
LEFT JOIN dbo.orders o ON c.customer_id = o.customer_id
LEFT JOIN dbo.customer_loyalty cl ON c.customer_id = cl.customer_id
WHERE c.active = 1
GROUP BY c.customer_id, c.first_name, c.last_name, c.email, c.city, c.state, 
         c.customer_type, c.created_date, cl.points_balance, cl.tier_level;
GO

