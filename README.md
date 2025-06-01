# 📊 Parquet Pipelines

> A minimal, SQL-first data transformation framework for teams migrating from stored procedures to modern analytics.

[![Python 3.8+](https://img.shields.io/badge/python-3.8+-blue.svg)](https://www.python.org/downloads/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20macOS%20%7C%20Linux-lightgrey)](https://github.com/Pass-The-Butter/parquet-pipelines)

**Parquet Pipelines** replaces complex ETL tools with a simple, lightweight framework that transforms your existing SQL knowledge into a portable, version-controlled data pipeline. Perfect for teams with strong SQL skills but limited Python/Git/orchestration experience.

## ✨ Features

- 🎯 **SQL-First**: Write transformations in pure SQL, not Python
- 🏠 **Zero Infrastructure**: Runs locally, no servers or orchestration needed
- 📱 **Portable**: Works on Windows laptops, Mac, Docker containers, or cloud VMs
- 📊 **Power BI Ready**: Outputs dimensional models perfect for business intelligence
- 🔍 **Metadata Rich**: Every output includes embedded lineage and documentation
- 📝 **Git Friendly**: Version control your entire data pipeline
- 🧠 **DuckLake Integration**: Modern lakehouse architecture with queryable catalog
- ⚡ **Named Pipelines**: Reusable, parameterized workflows for different business needs

## 🚀 Quick Start

### 1. Clone and Setup

```bash
git clone https://github.com/Pass-The-Butter/parquet-pipelines.git
cd parquet-pipelines
```

**Mac/Linux:**
```bash
chmod +x install-linux.sh
./install-linux.sh
```

**Windows:**
```powershell
# Run as Administrator
.\install-windows.ps1
```

### 2. Set Up Sample Database (Optional)

```bash
# Run the sample database script in SQL Server Management Studio
# File: sample_data/create_sample_database.sql
# Creates: SampleRetailDB with realistic e-commerce data
```

### 3. Configure Database Connection

```bash
# Edit your database connection
cp config/source_tables.yml config/source_tables_local.yml
# Update with your database details
```

Example configuration:
```yaml
connection:
  type: mssql
  server: your-server-name
  database: SampleRetailDB
  trusted_connection: true

tables:
  - name: customers
    schema: dbo
    description: Customer master data
  - name: orders
    schema: dbo
    description: Order transactions
```

### 4. Run Your First Pipeline

```bash
# Extract data from source
python -m parquet_pipelines extract --all

# Run transformations
python -m parquet_pipelines run --pipeline retail_analytics

# Check results
ls data/gold/
```

## 📁 Project Structure

```
parquet-pipelines/
├── 📂 config/                    # Configuration files
│   ├── source_tables.yml         # Database connections & table definitions
│   ├── pipeline.yml              # Main transformation pipeline
│   └── named_pipelines.yml       # Reusable, named pipelines
├── 📂 sql/                       # SQL transformation files
│   ├── 📂 silver/               # Data cleaning transformations
│   └── 📂 gold/                 # Business logic transformations
├── 📂 data/                      # Generated data (auto-created, gitignored)
│   ├── 📂 bronze/               # Raw extracted data
│   ├── 📂 silver/               # Cleaned data
│   └── 📂 gold/                 # Analytics-ready data
├── 📂 sample_data/               # Sample database setup
├── 📂 tests/                     # Test suite
├── 📄 ducklake_meta.duckdb      # DuckLake catalog metadata
└── 📄 README.md                 # This file
```

## 🎯 Use Cases

Perfect for teams that:
- ✅ Have strong SQL skills but limited Python/DevOps experience
- ✅ Want to migrate from stored procedures to modern analytics
- ✅ Need portable pipelines that run anywhere (laptop to cloud)
- ✅ Want Power BI ready dimensional models
- ✅ Prefer simple tools over complex orchestration frameworks
- ✅ Need to version control their data transformations
- ✅ Want embedded metadata and lineage tracking

## 🏗️ Architecture

### Medallion Architecture
- 🥉 **Bronze Layer**: Raw data extraction from source systems
- 🥈 **Silver Layer**: Cleaned, validated, and standardized data
- 🥇 **Gold Layer**: Business-ready facts and dimensions

### DuckLake Integration
- **Queryable Catalog**: Inspect schemas and lineage without manual file inspection
- **Schema Evolution**: Track changes over time
- **No External Dependencies**: Pure local file-based lakehouse
- **SQL Standard**: Use standard `CREATE OR REPLACE TABLE` syntax

### SQL File Format
All SQL transformations include metadata headers:

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
    LOWER(TRIM(email)) AS email
FROM bronze.customers
WHERE customer_id IS NOT NULL;
```

## 📊 Sample Data

Includes a complete **SampleRetailDB** database with:
- **15 customers** across multiple states with realistic demographics
- **25 products** across 8 categories (Electronics, Clothing, Home & Garden, etc.)
- **200+ realistic orders** with line items spanning 6 months
- **Customer loyalty program** data with points and tiers
- **Product reviews and ratings** for authenticity
- **Complete e-commerce workflow** from customers to fulfillment

Perfect for testing and learning the framework!

## 🖥️ Command Line Interface

### Core Commands

```bash
# Initialize new project
python -m parquet_pipelines init

# Extract data from source systems
python -m parquet_pipelines extract --all
python -m parquet_pipelines extract --table customers --force

# Run transformation pipelines
python -m parquet_pipelines run --pipeline retail_analytics
python -m parquet_pipelines run --named daily_refresh

# Check pipeline status
python -m parquet_pipelines status
```

### Named Pipelines

Create reusable, business-focused pipelines:

```yaml
daily_sales_refresh:
  description: Daily refresh of sales data for operational reporting
  extract:
    tables: [dbo.customers, dbo.orders, dbo.order_items]
    only_if:
      last_updated: '<TODAY'
  transform:
    steps:
      - sql/silver/customers_cleaned.sql
      - sql/silver/orders_cleaned.sql
      - sql/gold/fact_sales.sql

executive_dashboard:
  description: Weekly executive reporting with full analytics
  extract:
    tables: [dbo.customers, dbo.products, dbo.orders, dbo.order_items]
  transform:
    steps:
      - sql/silver/customers_cleaned.sql
      - sql/silver/products_cleaned.sql
      - sql/gold/dim_customers.sql
      - sql/gold/fact_sales.sql
      - sql/gold/customer_lifetime_value.sql
```

## 📈 Power BI Integration

The gold layer outputs are designed for direct consumption in Power BI:

1. **Import Data**: Use "Get Data" → "Parquet" in Power BI
2. **Point to**: Your `data/gold/` directory
3. **Import Tables**: All fact and dimension tables
4. **Relationships**: Tables include proper keys for automatic relationship detection

### Example Data Model
```
fact_sales (center table)
├── dim_customers (customer_id)
├── dim_products (product_id)
├── dim_date (order_date)
└── fact_customer_summary (customer_id + month_year)
```

## 🐳 Docker Support

### Development Environment
```bash
# Start full development environment with SQL Server and Jupyter
docker-compose up -d

# Run commands in container
docker-compose exec parquet-pipelines python -m parquet_pipelines extract --all
```

### Production Container
```bash
# Build and run
docker build -t parquet-pipelines .
docker run -v $(pwd):/app/workspace parquet-pipelines extract --all
```

## 🔧 Advanced Features

- **Incremental Processing**: Configure delta loads for large tables
- **Multiple Environments**: Dev/staging/prod configurations
- **Cloud Deployment**: Ready for Azure, AWS, GCP
- **Monitoring & Alerting**: Built-in health checks and logging
- **Performance Optimization**: Memory management and chunking
- **Security**: Environment variables, encrypted connections

## 🧪 Testing

Complete test suite included:

```bash
# Run all tests
pytest tests/ -v

# Test specific functionality
python -c "from parquet_pipelines.cli import ParquetPipelines; print('✅ Import successful!')"
```

## 🤝 Contributing

Contributions welcome! This framework is designed to be:
- **Simple to understand**: SQL-first approach
- **Easy to extend**: Modular architecture
- **Well documented**: Comprehensive examples
- **Test covered**: Reliable and maintainable

### Development Setup
```bash
git clone https://github.com/Pass-The-Butter/parquet-pipelines.git
cd parquet-pipelines
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate
pip install -e ".[dev]"
pytest
```

## 📋 Roadmap

- [ ] **Web UI**: Simple web interface for monitoring pipelines
- [ ] **More Databases**: PostgreSQL, MySQL, Oracle support
- [ ] **Cloud Storage**: Direct output to AWS S3, Azure Blob
- [ ] **Scheduling**: Optional lightweight scheduler
- [ ] **Data Validation**: Built-in data quality checks
- [ ] **Lineage Visualization**: Interactive pipeline visualization
- [ ] **Performance Metrics**: Execution time and resource usage tracking

## 🆘 Support

- **Documentation**: Comprehensive setup and troubleshooting guides
- **Issues**: [GitHub Issues](https://github.com/Pass-The-Butter/parquet-pipelines/issues)
- **Discussions**: [GitHub Discussions](https://github.com/Pass-The-Butter/parquet-pipelines/discussions)

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **DuckDB Team**: For the amazing analytical database engine
- **DuckLake**: For the lightweight lakehouse architecture
- **PyArrow**: For efficient columnar data processing
- **All SQL enthusiasts**: Who prove that great analytics starts with great SQL

---

**Made with ❤️ for data teams who love SQL but need modern tools.**

*Transform your stored procedures into portable, version-controlled data pipelines today!*