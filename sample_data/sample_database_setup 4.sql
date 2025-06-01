-- ============================================================================
-- 10. CREATE VIEWS FOR COMMON QUERIES
-- ============================================================================
-- ============================================================================
-- Sample Database Setup for Parquet Pipelines Testing
-- Database: SampleRetailDB
-- Description: E-commerce/retail sample data with customers, products, orders
-- ============================================================================


Run them separately in SQL Server Management Studio (SSMS) or any SQL client connected to your SQL Server instance.


    -- Switch to the new database
    USE SampleRetailDB;
GO

-- Create customer summary view (this was missing)
CREATE VIEW dbo.vw_customer_summary AS
SELECT 
    c.customer_id,
    c.first_name + ' ' + c.last_name as customer_name,
    c.email,
    c.city,
    c.state,
    COUNT(o.order_id) as total_orders,
    SUM(o.total_amount) as total_spent
FROM dbo.customers c
LEFT JOIN dbo.orders o ON c.customer_id = o.customer_id
GROUP BY c.customer_id, c.first_name, c.last_name, c.email, c.city, c.state;
GO

-- Product performance view (keep existing)
CREATE VIEW dbo.vw_product_performance AS
SELECT 
    p.product_id,
    p.product_name,
    pc.category_name,
    p.price,
    p.cost,
    p.stock_quantity,
    COUNT(oi.order_item_id) as times_ordered,
    SUM(oi.quantity) as total_quantity_sold,
    SUM(oi.line_total) as total_revenue,
    AVG(CAST(pr.rating AS FLOAT)) as avg_rating,
    COUNT(pr.review_id) as review_count
FROM dbo.products p
LEFT JOIN dbo.product_categories pc ON p.category_id = pc.category_id
LEFT JOIN dbo.order_items oi ON p.product_id = oi.product_id
LEFT JOIN dbo.product_reviews pr ON p.product_id = pr.product_id
WHERE p.active = 1
GROUP BY p.product_id, p.product_name, pc.category_name, p.price, p.cost, p.stock_quantity;
GO

    -- ============================================================================
    -- 11. CREATE INDEXES FOR PERFORMANCE
    -- ============================================================================
    USE SampleRetailDB;
GO
    -- Customer indexes
    CREATE INDEX IX_customers_email ON dbo.customers(email);
    CREATE INDEX IX_customers_state ON dbo.customers(state);
    CREATE INDEX IX_customers_created_date ON dbo.customers(created_date);

    -- Order indexes
    CREATE INDEX IX_orders_customer_id ON dbo.orders(customer_id);
    CREATE INDEX IX_orders_order_date ON dbo.orders(order_date);
    CREATE INDEX IX_orders_status ON dbo.orders(status);

    -- Order items indexes
    CREATE INDEX IX_order_items_order_id ON dbo.order_items(order_id);
    CREATE INDEX IX_order_items_product_id ON dbo.order_items(product_id);

    -- Product indexes
    CREATE INDEX IX_products_category_id ON dbo.products(category_id);
    CREATE INDEX IX_products_sku ON dbo.products(sku);

    -- ============================================================================
    -- 12. SAMPLE QUERIES TO TEST THE DATA
    -- ============================================================================
    USE SampleRetailDB;
GO
    -- Top customers by revenue
    SELECT TOP 10
        c.first_name + ' ' + c.last_name as customer_name,
        c.email,
        SUM(o.total_amount) as total_spent,
        COUNT(o.order_id) as order_count
    FROM dbo.customers c
    INNER JOIN dbo.orders o ON c.customer_id = o.customer_id
    GROUP BY c.customer_id, c.first_name, c.last_name, c.email
    ORDER BY total_spent DESC;

    -- Top selling products
    SELECT TOP 10
        p.product_name,
        pc.category_name,
        SUM(oi.quantity) as total_sold,
        SUM(oi.line_total) as total_revenue
    FROM dbo.products p
    INNER JOIN dbo.product_categories pc ON p.category_id = pc.category_id
    INNER JOIN dbo.order_items oi ON p.product_id = oi.product_id
    GROUP BY p.product_id, p.product_name, pc.category_name
    ORDER BY total_revenue DESC;

    -- Monthly sales summary
    SELECT 
        YEAR(order_date) as year,
        MONTH(order_date) as month,
        COUNT(order_id) as order_count,
        SUM(total_amount) as total_revenue,
        AVG(total_amount) as avg_order_value
    FROM dbo.orders
    GROUP BY YEAR(order_date), MONTH(order_date)
    ORDER BY year DESC, month DESC;

DECLARE @CustomerCount INT,
        @ProductCount INT,
        @OrderCount INT,
        @OrderItemCount INT;

SELECT @CustomerCount = COUNT(*) FROM dbo.customers;
SELECT @ProductCount = COUNT(*) FROM dbo.products;
SELECT @OrderCount = COUNT(*) FROM dbo.orders;
SELECT @OrderItemCount = COUNT(*) FROM dbo.order_items;

PRINT 'Sample database SampleRetailDB created successfully!';
PRINT 'Database contains:';
PRINT '- ' + CAST(@CustomerCount AS VARCHAR) + ' customers';
PRINT '- ' + CAST(@ProductCount AS VARCHAR) + ' products';
PRINT '- ' + CAST(@OrderCount AS VARCHAR) + ' orders';
PRINT '- ' + CAST(@OrderItemCount AS VARCHAR) + ' order items';
PRINT 'Ready for Parquet Pipelines testing!';
GO
