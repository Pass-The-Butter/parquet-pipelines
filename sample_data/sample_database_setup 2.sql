-- ============================================================================
-- Sample Database Setup for Parquet Pipelines Testing
-- Database: SampleRetailDB
-- Description: E-commerce/retail sample data with customers, products, orders
-- ============================================================================

    -- Switch to the new database
    USE SampleRetailDB;

    CREATE TABLE dbo.products (
        product_id INT IDENTITY(1,1) PRIMARY KEY,
        product_name NVARCHAR(100) NOT NULL,
        category_id INT FOREIGN KEY REFERENCES dbo.product_categories(category_id),
        price DECIMAL(10,2) NOT NULL,
        cost DECIMAL(10,2) NOT NULL,
        sku NVARCHAR(50) UNIQUE,
        description NVARCHAR(500),
        weight_lbs DECIMAL(8,2),
        dimensions NVARCHAR(50),
        supplier NVARCHAR(100),
        created_date DATETIME2 DEFAULT GETDATE(),
        updated_date DATETIME2 DEFAULT GETDATE(),
        active BIT DEFAULT 1,
        stock_quantity INT DEFAULT 0
    );

    -- Insert sample products
    INSERT INTO dbo.products (product_name, category_id, price, cost, sku, description, weight_lbs, supplier, stock_quantity) VALUES
    -- Electronics
    ('Wireless Bluetooth Headphones', 1, 79.99, 45.00, 'ELEC-001', 'High-quality wireless headphones with noise cancellation', 0.8, 'TechSupplier Inc', 150),
    ('Smartphone Case', 1, 24.99, 12.50, 'ELEC-002', 'Protective case for smartphones', 0.2, 'AccessoryWorld', 500),
    ('USB-C Charging Cable', 1, 19.99, 8.00, 'ELEC-003', 'Fast charging USB-C cable 6ft', 0.3, 'CableCorp', 300),
    ('Wireless Mouse', 1, 34.99, 18.00, 'ELEC-004', 'Ergonomic wireless optical mouse', 0.4, 'TechSupplier Inc', 200),
    ('Portable Power Bank', 1, 49.99, 25.00, 'ELEC-005', '10000mAh portable battery charger', 1.2, 'PowerTech', 180),

    -- Clothing
    ('Cotton T-Shirt', 2, 19.99, 8.50, 'CLTH-001', 'Comfortable 100% cotton t-shirt', 0.5, 'FashionCorp', 400),
    ('Denim Jeans', 2, 59.99, 30.00, 'CLTH-002', 'Classic fit denim jeans', 1.8, 'DenimMakers', 250),
    ('Running Shoes', 2, 89.99, 50.00, 'CLTH-003', 'Lightweight running shoes with cushioning', 2.1, 'SportsBrand', 180),
    ('Winter Jacket', 2, 129.99, 70.00, 'CLTH-004', 'Waterproof winter jacket with insulation', 3.5, 'OutdoorWear', 120),
    ('Baseball Cap', 2, 24.99, 12.00, 'CLTH-005', 'Adjustable baseball cap with team logo', 0.3, 'CapMakers', 300),

    -- Home & Garden
    ('Coffee Maker', 3, 99.99, 60.00, 'HOME-001', 'Programmable drip coffee maker 12-cup', 8.5, 'KitchenAppliances', 80),
    ('Garden Hose', 3, 39.99, 20.00, 'HOME-002', '50ft expandable garden hose', 3.2, 'GardenSupply', 150),
    ('LED Desk Lamp', 3, 34.99, 18.00, 'HOME-003', 'Adjustable LED desk lamp with USB port', 2.1, 'LightingCorp', 200),
    ('Storage Basket', 3, 29.99, 15.00, 'HOME-004', 'Woven storage basket with handles', 1.8, 'HomeDécor', 180),
    ('Plant Fertilizer', 3, 14.99, 6.00, 'HOME-005', 'All-purpose plant fertilizer 2lb bag', 2.0, 'GardenSupply', 250),

    -- Books
    ('Programming Guide', 4, 39.99, 20.00, 'BOOK-001', 'Complete guide to modern programming', 1.5, 'TechBooks', 100),
    ('Cookbook', 4, 24.99, 12.00, 'BOOK-002', 'International recipes cookbook', 2.1, 'CulinaryPress', 150),
    ('Mystery Novel', 4, 14.99, 7.50, 'BOOK-003', 'Bestselling mystery thriller novel', 0.8, 'FictionHouse', 200),
    ('Self-Help Book', 4, 19.99, 10.00, 'BOOK-004', 'Guide to personal development', 1.2, 'LifeBooks', 180),
    ('Children''s Picture Book', 4, 12.99, 6.00, 'BOOK-005', 'Colorful picture book for kids', 0.6, 'KidsPress', 220),

    -- Sports & Outdoors
    ('Yoga Mat', 5, 29.99, 15.00, 'SPRT-001', 'Non-slip yoga mat with carrying strap', 2.5, 'FitnessGear', 200),
    ('Tennis Racket', 5, 89.99, 50.00, 'SPRT-002', 'Professional tennis racket', 1.1, 'SportsBrand', 80),
    ('Camping Tent', 5, 149.99, 85.00, 'SPRT-003', '4-person waterproof camping tent', 12.5, 'OutdoorAdventure', 60),
    ('Water Bottle', 5, 19.99, 8.00, 'SPRT-004', 'Insulated stainless steel water bottle', 1.2, 'HydrationPro', 300),
    ('Hiking Backpack', 5, 79.99, 45.00, 'SPRT-005', '25L hiking backpack with multiple pockets', 2.8, 'OutdoorAdventure', 120);

    -- ============================================================================
    -- 4. ORDERS TABLE
    -- ============================================================================

    CREATE TABLE dbo.orders (
        order_id INT IDENTITY(1,1) PRIMARY KEY,
        customer_id INT FOREIGN KEY REFERENCES dbo.customers(customer_id),
        order_date DATETIME2 NOT NULL,
        ship_date DATETIME2,
        delivery_date DATETIME2,
        status NVARCHAR(20) DEFAULT 'PENDING',
        shipping_address NVARCHAR(200),
        shipping_city NVARCHAR(50),
        shipping_state NVARCHAR(50),
        shipping_zip NVARCHAR(10),
        payment_method NVARCHAR(50),
        subtotal DECIMAL(10,2),
        tax_amount DECIMAL(10,2),
        shipping_cost DECIMAL(10,2),
        total_amount DECIMAL(10,2),
        created_date DATETIME2 DEFAULT GETDATE(),
        notes NVARCHAR(500)
    );

    -- ============================================================================
    -- 5. ORDER_ITEMS TABLE
    -- ============================================================================

    CREATE TABLE dbo.order_items (
        order_item_id INT IDENTITY(1,1) PRIMARY KEY,
        order_id INT FOREIGN KEY REFERENCES dbo.orders(order_id),
        product_id INT FOREIGN KEY REFERENCES dbo.products(product_id),
        quantity INT NOT NULL,
        unit_price DECIMAL(10,2) NOT NULL,
        line_total AS (quantity * unit_price) PERSISTED,
        discount_amount DECIMAL(10,2) DEFAULT 0
    );

    -- ============================================================================
    -- 6. GENERATE SAMPLE ORDERS AND ORDER ITEMS
    -- ============================================================================

    DECLARE @i INT = 1;
    DECLARE @customer_id INT;
    DECLARE @order_date DATETIME2;
    DECLARE @order_id INT;
    DECLARE @num_items INT;
    DECLARE @j INT;
    DECLARE @product_id INT;
    DECLARE @quantity INT;
    DECLARE @unit_price DECIMAL(10,2);

    -- Generate 200 sample orders over the last 6 months
    WHILE @i <= 200
    BEGIN
        -- Random customer
        SET @customer_id = (SELECT TOP 1 customer_id FROM dbo.customers ORDER BY NEWID());
        
        -- Random order date in last 6 months
        SET @order_date = DATEADD(day, -ABS(CHECKSUM(NEWID()) % 180), GETDATE());
        
        -- Insert order
        INSERT INTO dbo.orders (customer_id, order_date, status, payment_method, shipping_cost, created_date)
        VALUES (
            @customer_id,
            @order_date,
            CASE (ABS(CHECKSUM(NEWID())) % 5)
                WHEN 0 THEN 'PENDING'
                WHEN 1 THEN 'PROCESSING'
                WHEN 2 THEN 'SHIPPED'
                WHEN 3 THEN 'DELIVERED'
                ELSE 'COMPLETED'
            END,
            CASE (ABS(CHECKSUM(NEWID())) % 4)
                WHEN 0 THEN 'Credit Card'
                WHEN 1 THEN 'Debit Card'
                WHEN 2 THEN 'PayPal'
                ELSE 'Bank Transfer'
            END,
            ROUND((ABS(CHECKSUM(NEWID())) % 20) + 5.99, 2), -- Shipping cost between $5.99-$24.99
            @order_date
        );
        
        SET @order_id = SCOPE_IDENTITY();
        
        -- Random number of items per order (1-5)
        SET @num_items = (ABS(CHECKSUM(NEWID())) % 5) + 1;
        SET @j = 1;
        
        -- Add items to this order
        WHILE @j <= @num_items
        BEGIN
            -- Random product
            SET @product_id = (SELECT TOP 1 product_id FROM dbo.products ORDER BY NEWID());
            
            -- Random quantity (1-3)
            SET @quantity = (ABS(CHECKSUM(NEWID())) % 3) + 1;
            
            -- Get product price
            SET @unit_price = (SELECT price FROM dbo.products WHERE product_id = @product_id);
            
            -- Insert order item
            INSERT INTO dbo.order_items (order_id, product_id, quantity, unit_price)
            VALUES (@order_id, @product_id, @quantity, @unit_price);
            
            SET @j = @j + 1;
        END;
        
        SET @i = @i + 1;
    END;

    -- ============================================================================
    -- 7. UPDATE ORDER TOTALS
    -- ============================================================================

    UPDATE o
    SET 
        subtotal = oi.subtotal,
        tax_amount = ROUND(oi.subtotal * 0.0875, 2), -- 8.75% tax
        total_amount = ROUND(oi.subtotal * 1.0875, 2) + o.shipping_cost
    FROM dbo.orders o
    INNER JOIN (
        SELECT 
            order_id,
            SUM(line_total) as subtotal
        FROM dbo.order_items
        GROUP BY order_id
    ) oi ON o.order_id = oi.order_id;

    -- ============================================================================
    -- 8. CUSTOMER LOYALTY PROGRAM TABLE
    -- ============================================================================

    CREATE TABLE dbo.customer_loyalty (
        loyalty_id INT IDENTITY(1,1) PRIMARY KEY,
        customer_id INT FOREIGN KEY REFERENCES dbo.customers(customer_id),
        program_name NVARCHAR(50),
        points_balance INT DEFAULT 0,
        tier_level NVARCHAR(20) DEFAULT 'Bronze',
        enrollment_date DATETIME2 DEFAULT GETDATE(),
        last_activity_date DATETIME2,
        active BIT DEFAULT 1
    );

    -- Insert loyalty data for customers
    INSERT INTO dbo.customer_loyalty (customer_id, program_name, points_balance, tier_level, enrollment_date)
    SELECT 
        customer_id,
        'Rewards Plus',
        (ABS(CHECKSUM(NEWID())) % 10000) + 100, -- Random points 100-10099
        CASE 
            WHEN customer_type = 'VIP' THEN 'Platinum'
            WHEN customer_type = 'Premium' THEN 'Gold'
            ELSE 'Silver'
        END,
        DATEADD(day, -(ABS(CHECKSUM(NEWID())) % 365), GETDATE()) -- Random enrollment in last year
    FROM dbo.customers;

    -- ============================================================================
    -- 9. PRODUCT REVIEWS TABLE
    -- ============================================================================

    CREATE TABLE dbo.product_reviews (
        review_id INT IDENTITY(1,1) PRIMARY KEY,
        product_id INT FOREIGN KEY REFERENCES dbo.products(product_id),
        customer_id INT FOREIGN KEY REFERENCES dbo.customers(customer_id),
        rating INT CHECK (rating BETWEEN 1 AND 5),
        review_title NVARCHAR(100),
        review_text NVARCHAR(1000),
        review_date DATETIME2 DEFAULT GETDATE(),
        helpful_votes INT DEFAULT 0,
        verified_purchase BIT DEFAULT 0
    );

    -- Insert sample reviews
    INSERT INTO dbo.product_reviews (product_id, customer_id, rating, review_title, review_text, review_date, verified_purchase) VALUES
    (1, 1, 5, 'Great headphones!', 'Excellent sound quality and battery life. Very comfortable for long listening sessions.', DATEADD(day, -10, GETDATE()), 1),
    (1, 3, 4, 'Good value', 'Nice headphones for the price. Sound is clear but could use more bass.', DATEADD(day, -8, GETDATE()), 1),
    (2, 2, 5, 'Perfect fit', 'This case fits my phone perfectly and provides great protection.', DATEADD(day, -15, GETDATE()), 1),
    (5, 4, 4, 'Reliable power bank', 'Charges my phone multiple times. A bit heavy but works well.', DATEADD(day, -12, GETDATE()), 1),
    (8, 5, 5, 'Comfortable shoes', 'Very comfortable for running. Great cushioning and support.', DATEADD(day, -20, GETDATE()), 1),
    (11, 6, 5, 'Love this coffee maker', 'Makes great coffee and the timer function is very convenient.', DATEADD(day, -18, GETDATE()), 1),
    (15, 7, 4, 'Good cookbook', 'Lots of interesting recipes. Instructions could be clearer.', DATEADD(day, -25, GETDATE()), 1),
    (20, 8, 5, 'Excellent yoga mat', 'Great grip and cushioning. Perfect for my daily yoga practice.', DATEADD(day, -14, GETDATE()), 1);

-- Add this line to separate batches (removed GO as it is not valid in this context)
