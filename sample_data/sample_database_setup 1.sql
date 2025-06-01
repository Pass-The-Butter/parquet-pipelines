-- ============================================================================
-- Sample Database Setup for Parquet Pipelines Testing
-- ============================================================================

USE master;
GO

-- Drop database if it exists
IF EXISTS (SELECT name FROM sys.databases WHERE name = 'SampleRetailDB')
BEGIN
    ALTER DATABASE SampleRetailDB SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE SampleRetailDB;
END
GO

CREATE DATABASE SampleRetailDB;
GO

USE SampleRetailDB;
GO

-- Create tables first
CREATE TABLE dbo.customers (
    customer_id INT IDENTITY(1,1) PRIMARY KEY,
    first_name NVARCHAR(50) NOT NULL,
    last_name NVARCHAR(50) NOT NULL,
    email NVARCHAR(100) NOT NULL UNIQUE,
    phone NVARCHAR(20),
    address NVARCHAR(200),
    city NVARCHAR(50),
    state NVARCHAR(50),
    zip_code NVARCHAR(10),
    date_of_birth DATE,
    created_date DATETIME2 DEFAULT GETDATE(),
    updated_date DATETIME2 DEFAULT GETDATE(),
    active BIT DEFAULT 1,
    customer_type NVARCHAR(20) DEFAULT 'Regular'
);
GO

CREATE TABLE dbo.product_categories (
    category_id INT IDENTITY(1,1) PRIMARY KEY,
    category_name NVARCHAR(50) NOT NULL,
    description NVARCHAR(200),
    active BIT DEFAULT 1
);
GO

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
GO

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
GO

CREATE TABLE dbo.order_items (
    order_item_id INT IDENTITY(1,1) PRIMARY KEY,
    order_id INT FOREIGN KEY REFERENCES dbo.orders(order_id),
    product_id INT FOREIGN KEY REFERENCES dbo.products(product_id),
    quantity INT NOT NULL,
    unit_price DECIMAL(10,2) NOT NULL,
    line_total AS (quantity * unit_price) PERSISTED,
    discount_amount DECIMAL(10,2) DEFAULT 0
);
GO

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
GO

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
GO

-- Now insert data in separate batches
INSERT INTO dbo.customers (first_name, last_name, email, phone, address, city, state, zip_code, date_of_birth, created_date, customer_type) 
VALUES
    ('John', 'Smith', 'john.smith@email.com', '555-0101', '123 Main St', 'New York', 'NY', '10001', '1985-03-15', DATEADD(day, -180, GETDATE()), 'Premium'),
    ('Sarah', 'Johnson', 'sarah.johnson@email.com', '555-0102', '456 Oak Ave', 'Los Angeles', 'CA', '90210', '1990-07-22', DATEADD(day, -150, GETDATE()), 'Regular'),
    ('Michael', 'Brown', 'michael.brown@email.com', '555-0103', '789 Pine St', 'Chicago', 'IL', '60601', '1988-11-08', DATEADD(day, -120, GETDATE()), 'VIP'),
    ('Emily', 'Davis', 'emily.davis@email.com', '555-0104', '321 Elm Dr', 'Houston', 'TX', '77001', '1992-05-14', DATEADD(day, -100, GETDATE()), 'Regular'),
    ('David', 'Wilson', 'david.wilson@email.com', '555-0105', '654 Maple Ln', 'Phoenix', 'AZ', '85001', '1987-09-30', DATEADD(day, -90, GETDATE()), 'Premium'),
    ('Jessica', 'Garcia', 'jessica.garcia@email.com', '555-0106', '987 Cedar Rd', 'Philadelphia', 'PA', '19101', '1991-12-03', DATEADD(day, -80, GETDATE()), 'Regular'),
    ('Christopher', 'Martinez', 'chris.martinez@email.com', '555-0107', '147 Birch St', 'San Antonio', 'TX', '78201', '1989-04-18', DATEADD(day, -70, GETDATE()), 'VIP'),
    ('Amanda', 'Rodriguez', 'amanda.rodriguez@email.com', '555-0108', '258 Spruce Ave', 'San Diego', 'CA', '92101', '1993-08-25', DATEADD(day, -60, GETDATE()), 'Regular'),
    ('Matthew', 'Lopez', 'matthew.lopez@email.com', '555-0109', '369 Fir Blvd', 'Dallas', 'TX', '75201', '1986-01-12', DATEADD(day, -50, GETDATE()), 'Premium'),
    ('Ashley', 'Gonzalez', 'ashley.gonzalez@email.com', '555-0110', '741 Ash Ct', 'San Jose', 'CA', '95101', '1994-06-07', DATEADD(day, -40, GETDATE()), 'Regular'),
    -- Additional customers for more realistic data
    ('Robert', 'Taylor', 'robert.taylor@email.com', '555-0111', '852 Willow Way', 'Austin', 'TX', '73301', '1984-10-20', DATEADD(day, -30, GETDATE()), 'VIP'),
    ('Jennifer', 'Anderson', 'jennifer.anderson@email.com', '555-0112', '963 Poplar St', 'Jacksonville', 'FL', '32099', '1995-02-14', DATEADD(day, -25, GETDATE()), 'Regular'),
    ('William', 'Thomas', 'william.thomas@email.com', '555-0113', '159 Hickory Dr', 'Fort Worth', 'TX', '76101', '1983-07-11', DATEADD(day, -20, GETDATE()), 'Premium'),
    ('Michelle', 'Jackson', 'michelle.jackson@email.com', '555-0114', '357 Walnut Ave', 'Columbus', 'OH', '43085', '1996-09-28', DATEADD(day, -15, GETDATE()), 'Regular'),
    ('James', 'White', 'james.white@email.com', '555-0115', '486 Chestnut Ln', 'Charlotte', 'NC', '28105', '1982-12-05', DATEADD(day, -10, GETDATE()), 'VIP');
GO

INSERT INTO dbo.product_categories (category_name, description) 
VALUES
    ('Electronics', 'Electronic devices and accessories'),
    ('Clothing', 'Apparel and fashion items'),
    ('Home & Garden', 'Home improvement and garden supplies'),
    ('Books', 'Books and educational materials'),
    ('Sports & Outdoors', 'Sporting goods and outdoor equipment'),
    ('Health & Beauty', 'Health and beauty products'),
    ('Toys & Games', 'Toys and gaming products'),
    ('Automotive', 'Car parts and automotive accessories');
GO

INSERT INTO dbo.products (product_name, category_id, price, cost, sku, description, weight_lbs, supplier, stock_quantity) 
VALUES
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
GO

-- Generate orders using simpler logic
DECLARE @i INT = 1;
WHILE @i <= 200
BEGIN
    DECLARE @customer_id INT;
    DECLARE @order_date DATETIME2;
    DECLARE @order_id INT;
    DECLARE @num_items INT;
    DECLARE @j INT;
    DECLARE @product_id INT;
    DECLARE @quantity INT;
    DECLARE @unit_price DECIMAL(10,2);

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
GO

-- Update order totals
UPDATE o
SET 
    subtotal = oi.subtotal,
    tax_amount = ROUND(oi.subtotal * 0.0875, 2),
    total_amount = ROUND(oi.subtotal * 1.0875, 2) + o.shipping_cost
FROM dbo.orders o
INNER JOIN (
    SELECT order_id, SUM(line_total) as subtotal
    FROM dbo.order_items
    GROUP BY order_id
) oi ON o.order_id = oi.order_id;
GO

-- Insert loyalty data
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
GO

-- Insert reviews
INSERT INTO dbo.product_reviews (product_id, customer_id, rating, review_title, review_text, review_date, verified_purchase) 
VALUES
    (1, 1, 5, 'Great headphones!', 'Excellent sound quality and battery life. Very comfortable for long listening sessions.', DATEADD(day, -10, GETDATE()), 1),
    (1, 3, 4, 'Good value', 'Nice headphones for the price. Sound is clear but could use more bass.', DATEADD(day, -8, GETDATE()), 1),
    (2, 2, 5, 'Perfect fit', 'This case fits my phone perfectly and provides great protection.', DATEADD(day, -15, GETDATE()), 1),
    (5, 4, 4, 'Reliable power bank', 'Charges my phone multiple times. A bit heavy but works well.', DATEADD(day, -12, GETDATE()), 1),
    (8, 5, 5, 'Comfortable shoes', 'Very comfortable for running. Great cushioning and support.', DATEADD(day, -20, GETDATE()), 1),
    (11, 6, 5, 'Love this coffee maker', 'Makes great coffee and the timer function is very convenient.', DATEADD(day, -18, GETDATE()), 1),
    (15, 7, 4, 'Good cookbook', 'Lots of interesting recipes. Instructions could be clearer.', DATEADD(day, -25, GETDATE()), 1),
    (20, 8, 5, 'Excellent yoga mat', 'Great grip and cushioning. Perfect for my daily yoga practice.', DATEADD(day, -14, GETDATE()), 1);
GO

PRINT 'Database setup completed successfully';
GO

-- Now create views in separate batches
CREATE VIEW dbo.vw_customer_summary AS
SELECT 
    c.customer_id,
    c.first_name,
    c.last_name
    -- ... rest of view definition
FROM dbo.customers c
GO