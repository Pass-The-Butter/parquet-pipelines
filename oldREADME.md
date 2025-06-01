# Parquet Pipelines

A minimal, SQL-first data transformation framework for teams migrating from stored procedures to modern analytics.

Parquet Pipelines replaces complex ETL tools with a simple, lightweight framework that transforms your existing SQL knowledge into a portable, version-controlled data pipeline. Perfect for teams with strong SQL skills but limited Python/Git/orchestration experience.

## Features

- SQL-First: Write transformations in pure SQL, not Python
- Zero Infrastructure: Runs locally, no servers or orchestration needed
- Portable: Works on Windows laptops, Docker containers, or cloud VMs
- Power BI Ready: Outputs dimensional models perfect for business intelligence
- Metadata Rich: Every output includes embedded lineage and documentation
- Git Friendly: Version control your entire data pipeline

## Installation

### Windows

```powershell
# Run as Administrator
.\install-windows.ps1
```

### Linux/Mac

```bash
chmod +x install-linux.sh
./install-linux.sh
```

### Manual Setup

1. Create and activate virtual environment:
```bash
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
```

2. Install dependencies:
```bash
pip install -r requirements.txt
pip install -e .
```

## Quick Start

1. Initialize your project:
```bash
python -m parquet_pipelines init
```

2. Configure your database connection in `config/source_tables.yml`

3. Extract your data:
```bash
python -m parquet_pipelines extract --all
```

4. Run transformations:
```bash
python -m parquet_pipelines run --pipeline main
```

## Project Structure

```
my-data-project/
├── 📂 config/
│   ├── source_tables.yml      # Database connections & table definitions
│   ├── pipeline.yml           # Main transformation pipeline
│   └── named_pipelines.yml    # Reusable, named pipelines
├── 📂 sql/
│   ├── 📂 silver/             # Data cleaning transformations
│   │   ├── customers_cleaned.sql
│   │   └── orders_cleaned.sql
│   └── 📂 gold/               # Business logic transformations
│       ├── fact_sales.sql
│       └── dim_customers.sql
├── 📂 data/                   # Generated data (auto-created, gitignored)
│   ├── 📂 bronze/            # Raw extracted data
│   ├── 📂 silver/            # Cleaned data
│   └── 📂 gold/              # Analytics-ready data
├── ducklake_meta.duckdb      # DuckLake catalog metadata
├── .gitignore               # Excludes data directory
└── README.md               # Project documentation
```

## Configuration

### Database Connection (`config/source_tables.yml`)

```yaml
connection:
  type: mssql
  server: localhost\SQLEXPRESS
  database: YourDatabase
  trusted_connection: true  # Use Windows auth
  # username: your_user     # For SQL auth
  # password: your_pass

tables:
  - name: customers
    schema: dbo
    description: Customer master data
    query: SELECT * FROM dbo.customers WHERE active = 1
  
  - name: orders
    schema: dbo
    description: Order transactions
    # Uses default: SELECT * FROM dbo.orders
```

### Pipeline Definition (`config/pipeline.yml`)

```yaml
name: main
description: Main transformation pipeline
steps:
  - sql/silver/customers_cleaned.sql
  - sql/silver/orders_cleaned.sql
  - sql/gold/fact_sales.sql
  - sql/gold/dim_customers.sql
```

### Named Pipelines (`config/named_pipelines.yml`)

```yaml
daily_refresh:
  description: Daily data refresh for reporting
  extract:
    tables: [dbo.customers, dbo.orders]
    only_if:
      last_updated: '<TODAY'
  transform:
    steps:
      - sql/silver/customers_cleaned.sql
      - sql/gold/dim_customers.sql

monthly_report:
  description: Monthly executive reporting
  extract:
    tables: [dbo.sales, dbo.products, dbo.regions]
  transform:
    steps:
      - sql/silver/sales_cleaned.sql
      - sql/gold/fact_monthly_sales.sql
      - sql/gold/dim_product_performance.sql
```

## SQL File Format

All SQL transformation files must include a metadata header:

```sql
-- name: customers_cleaned
-- layer: silver
-- description: Clean and standardize customer data
-- depends_on: bronze.customers

CREATE OR REPLACE TABLE silver.customers_cleaned AS
SELECT 
    customer_id,
    TRIM(UPPER(first_name)) AS first_name,
    TRIM(UPPER(last_name)) AS last_name,
    LOWER(TRIM(email)) AS email,
    phone,
    address,
    city,
    state,
    zip_code,
    created_date,
    updated_date
FROM bronze.customers
WHERE customer_id IS NOT NULL
    AND email IS NOT NULL
    AND email LIKE '%@%.%';
```

### Gold Layer Example (Fact Table)

```sql
-- name: fact_sales
-- layer: gold
-- description: Daily sales facts with customer and product dimensions
-- depends_on: silver.orders_cleaned, silver.customers_cleaned

CREATE OR REPLACE TABLE gold.fact_sales AS
SELECT 
    o.order_id,
    o.customer_id,
    o.product_id,
    o.order_date,
    o.quantity,
    o.unit_price,
    o.quantity * o.unit_price AS total_amount,
    c.customer_segment,
    DATE_TRUNC('month', o.order_date) AS order_month,
    DATE_TRUNC('quarter', o.order_date) AS order_quarter
FROM silver.orders_cleaned o
LEFT JOIN silver.customers_cleaned c ON o.customer_id = c.customer_id
WHERE o.quantity > 0 AND o.unit_price > 0;
```

## Command Line Interface

### Core Commands

```bash
# Initialize new project
python -m parquet_pipelines init

# Extract data from source systems
python -m parquet_pipelines extract --all
python -m parquet_pipelines extract --table customers
python -m parquet_pipelines extract --table orders --force

# Run transformation pipelines
python -m parquet_pipelines run --pipeline main
python -m parquet_pipelines run --named daily_refresh

# Check pipeline status
python -m parquet_pipelines status
```

### Using the Alias (after installation)

```bash
# If you installed the alias during setup
pp init
pp extract --all
pp run --named daily_refresh
```

## Docker Usage

### Development with Docker Compose

```bash
# Start full development environment
docker-compose up -d

# Run commands in container
docker-compose exec parquet-pipelines python -m parquet_pipelines init
docker-compose exec parquet-pipelines python -m parquet_pipelines extract --all

# Access Jupyter for data exploration
# Navigate to http://localhost:8888
```

### Production Container

```bash
# Build container
docker build -t parquet-pipelines .

# Run pipeline
docker run -v $(pwd):/app/workspace parquet-pipelines extract --all
docker run -v $(pwd):/app/workspace parquet-pipelines run --pipeline main
```

## Medallion Architecture

Parquet Pipelines implements a simplified medallion architecture:

### Bronze Layer
- **Purpose**: Raw data extraction from source systems
- **Format**: Parquet files with embedded metadata
- **Location**: `data/bronze/`
- **Example**: `customers.parquet`, `orders.parquet`

### Silver Layer  
- **Purpose**: Cleaned, validated, and standardized data
- **Transformations**: Data quality, standardization, deduplication
- **Location**: `data/silver/`
- **Example**: `customers_cleaned.parquet`

### Gold Layer
- **Purpose**: Business-ready facts and dimensions
- **Transformations**: Business logic, aggregations, dimensional modeling
- **Location**: `data/gold/`
- **Example**: `fact_sales.parquet`, `dim_customers.parquet`

## DuckLake Integration

Parquet Pipelines includes full integration with [DuckLake](https://duckdb.org/2025/05/27/ducklake.html), providing:

- **Queryable Catalog**: Inspect schemas and lineage without manual file inspection
- **Schema Evolution**: Track changes over time
- **No External Dependencies**: Pure local file-based lakehouse
- **SQL Standard**: Use standard `CREATE OR REPLACE TABLE` syntax

```sql
-- Query your catalog
SELECT * FROM information_schema.tables WHERE table_schema = 'gold';

-- Explore table structure  
DESCRIBE gold.fact_sales;

-- Query across layers
SELECT 
    g.customer_segment,
    COUNT(*) as customer_count
FROM gold.dim_customers g
JOIN silver.customers_cleaned s ON g.customer_id = s.customer_id
GROUP BY g.customer_segment;
```

## Power BI Integration

The gold layer outputs are designed for direct consumption in Power BI:

1. **Import Data**: Use "Get Data" → "Parquet" in Power BI
2. **Point to**: Your `data/gold/` directory
3. **Import Tables**: All fact and dimension tables
4. **Relationships**: Tables include proper keys for automatic relationship detection

### Example Power BI Data Model

```
fact_sales
├── customer_id → dim_customers.customer_id
├── product_id → dim_products.product_id  
├── order_date → dim_date.date
└── [measures: quantity, unit_price, total_amount]

dim_customers
├── customer_id [key]
├── customer_name
├── customer_segment
└── signup_month

dim_products
├── product_id [key]
├── product_name
├── category
└── price_tier
```

## Troubleshooting

### Common Issues

**1. ODBC Driver Not Found**
```bash
# Windows: Install via install-windows.ps1 script
# Linux: sudo apt-get install msodbcsql17
# Mac: brew install msodbcsql17
```

**2. Permission Denied on Database**
```yaml
# Check your config/source_tables.yml
connection:
  trusted_connection: true  # For Windows auth
  # OR
  username: your_username
  password: your_password
```

**3. Table Not Found in Pipeline**
```bash
# Check table exists in source_tables.yml
python -m parquet_pipelines extract --table your_table_name --force
```

**4. SQL Transformation Fails**
- Verify metadata header format in SQL files
- Check table dependencies exist
- Ensure `CREATE OR REPLACE TABLE` syntax

### Logging and Debugging

```bash
# Enable verbose logging
export PYTHONPATH=$(pwd)
python -c "
import logging
logging.basicConfig(level=logging.DEBUG)
from parquet_pipelines.cli import main
main()
" extract --all
```

## Advanced Usage

### Custom SQL Transformations

```sql
-- Advanced aggregation example
-- name: customer_lifetime_value
-- layer: gold
-- description: Calculate customer lifetime value and segments
-- depends_on: silver.orders_cleaned, silver.customers_cleaned

CREATE OR REPLACE TABLE gold.customer_lifetime_value AS
WITH customer_metrics AS (
    SELECT 
        c.customer_id,
        c.first_name,
        c.last_name,
        c.email,
        COUNT(o.order_id) as total_orders,
        SUM(o.quantity * o.unit_price) as total_spent,
        AVG(o.quantity * o.unit_price) as avg_order_value,
        MIN(o.order_date) as first_order_date,
        MAX(o.order_date) as last_order_date,
        DATEDIFF('day', MIN(o.order_date), MAX(o.order_date)) as customer_lifespan_days
    FROM silver.customers_cleaned c
    LEFT JOIN silver.orders_cleaned o ON c.customer_id = o.customer_id
    GROUP BY c.customer_id, c.first_name, c.last_name, c.email
)
SELECT 
    *,
    CASE 
        WHEN total_spent >= 10000 THEN 'VIP'
        WHEN total_spent >= 1000 THEN 'Premium'
        WHEN total_spent >= 100 THEN 'Standard'
        ELSE 'New'
    END as customer_tier,
    CASE 
        WHEN last_order_date >= CURRENT_DATE - INTERVAL '30 days' THEN 'Active'
        WHEN last_order_date >= CURRENT_DATE - INTERVAL '90 days' THEN 'At Risk'
        ELSE 'Inactive'
    END as status
FROM customer_metrics;
```

### Incremental Processing

```yaml
# For large tables, use incremental extraction
tables:
  - name: large_transactions
    schema: dbo
    description: Large transaction table with incremental load
    query: |
      SELECT * FROM dbo.transactions 
      WHERE modified_date >= DATEADD(day, -1, GETDATE())
```

### Multiple Environment Support

```bash
# Development
cp config/source_tables.yml config/source_tables_dev.yml

# Production  
cp config/source_tables.yml config/source_tables_prod.yml

# Use specific config
PARQUET_PIPELINES_CONFIG=prod python -m parquet_pipelines extract --all
```

## Contributing

We welcome contributions! Here's how to get started:

1. **Fork the repository**
2. **Create a feature branch**: `git checkout -b feature/amazing-feature`
3. **Make your changes** and add tests
4. **Run tests**: `pytest tests/`
5. **Submit a pull request`

### Development Setup

```bash
git clone https://github.com/yourorg/parquet-pipelines.git
cd parquet-pipelines
python -m venv venv
source venv/bin/activate
pip install -e ".[dev]"
pytest
```

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

- **Documentation**: This README and inline help (`python -m parquet_pipelines --help`)
- **Issues**: [GitHub Issues](https://github.com/yourorg/parquet-pipelines/issues)
- **Discussions**: [GitHub Discussions](https://github.com/yourorg/parquet-pipelines/discussions)

## Roadmap

- [ ] **Web UI**: Simple web interface for monitoring pipelines
- [ ] **More Databases**: PostgreSQL, MySQL, Oracle support
- [ ] **Cloud Storage**: Direct output to AWS S3, Azure Blob
- [ ] **Scheduling**: Optional lightweight scheduler
- [ ] **Data Validation**: Built-in data quality checks
- [ ] **Lineage Visualization**: Interactive pipeline visualization

---

**Made with ❤️ for data teams who love SQL but need modern tools.**
