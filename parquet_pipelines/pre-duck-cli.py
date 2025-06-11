#!/usr/bin/env python3
"""
Parquet Pipelines CLI Application
A minimal, SQL-first data transformation framework for teams migrating from stored procedures.
"""

import os
import sys
import argparse
import logging
import yaml
import json
from pathlib import Path
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Any
import duckdb
import pandas as pd
import sqlalchemy
from sqlalchemy import create_engine, text
import pyarrow as pa
import pyarrow.parquet as pq

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class ParquetPipelines:
    """Main application class for Parquet Pipelines framework."""
    
    def __init__(self, base_dir: Path = None):
        """Initialize the pipeline framework."""
        self.base_dir = base_dir or Path.cwd()
        self.data_dir = self.base_dir / "data"
        self.config_dir = self.base_dir / "config"
        self.sql_dir = self.base_dir / "sql"
        self.scripts_dir = self.base_dir / "scripts"
        
        # DuckLake metastore connection
        self.ducklake_path = self.base_dir / "ducklake_meta.duckdb"
        self.duck_conn = None
        
        # Ensure directory structure exists
        self._ensure_directory_structure()
        
    def _ensure_directory_structure(self):
        """Create required directory structure if it doesn't exist."""
        directories = [
            self.data_dir / "bronze",
            self.data_dir / "silver", 
            self.data_dir / "gold",
            self.config_dir,
            self.sql_dir / "silver",
            self.sql_dir / "gold",
            self.scripts_dir
        ]
        
        for directory in directories:
            directory.mkdir(parents=True, exist_ok=True)
            logger.info(f"Ensured directory exists: {directory}")
    
    def _get_duck_connection(self):
        """Get or create DuckDB connection for DuckLake metastore."""
        if self.duck_conn is None:
            self.duck_conn = duckdb.connect(str(self.ducklake_path))
            # Initialize DuckLake schemas
            self.duck_conn.execute("CREATE SCHEMA IF NOT EXISTS bronze")
            self.duck_conn.execute("CREATE SCHEMA IF NOT EXISTS silver") 
            self.duck_conn.execute("CREATE SCHEMA IF NOT EXISTS gold")
            logger.info(f"Connected to DuckLake metastore: {self.ducklake_path}")
        return self.duck_conn
    
    def load_config(self, config_name: str) -> Dict[str, Any]:
        """Load configuration from YAML file."""
        config_path = self.config_dir / f"{config_name}.yml"
        if not config_path.exists():
            raise FileNotFoundError(f"Configuration file not found: {config_path}")
        
        with open(config_path, 'r') as f:
            config = yaml.safe_load(f)
        
        logger.info(f"Loaded configuration: {config_path}")
        return config
    
    def get_table_metadata(self, schema: str, table_name: str) -> Optional[Dict]:
        """Get table metadata from DuckLake catalog."""
        conn = self._get_duck_connection()
        try:
            result = conn.execute(f"""
                SELECT * FROM information_schema.tables 
                WHERE table_schema = '{schema}' AND table_name = '{table_name}'
            """).fetchone()
            
            if result:
                # Get additional metadata if stored
                meta_result = conn.execute(f"""
                    SELECT comment FROM information_schema.tables
                    WHERE table_schema = '{schema}' AND table_name = '{table_name}'
                """).fetchone()
                
                return {
                    'exists': True,
                    'last_updated': datetime.now(),  # This would be enhanced with actual timestamp tracking
                    'comment': meta_result[0] if meta_result and meta_result[0] else None
                }
        except Exception as e:
            logger.debug(f"Table {schema}.{table_name} not found in catalog: {e}")
        
        return None
    
    def is_table_stale(self, schema: str, table_name: str, max_age_hours: int = 24) -> bool:
        """Check if a table needs refreshing based on age."""
        metadata = self.get_table_metadata(schema, table_name)
        if not metadata:
            return True  # Table doesn't exist, needs extraction
        
        # Simple staleness check - in production you'd track actual update times
        parquet_path = self.data_dir / schema / f"{table_name}.parquet"
        if not parquet_path.exists():
            return True
        
        file_age = datetime.now() - datetime.fromtimestamp(parquet_path.stat().st_mtime)
        return file_age > timedelta(hours=max_age_hours)
    
    def extract_table(self, source_config: Dict, table_config: Dict, force: bool = False):
        """Extract a single table from source to bronze layer."""
        table_name = table_config['name']
        schema = table_config.get('schema', 'dbo')
        full_table_name = f"{schema}.{table_name}"
        
        # Check if extraction is needed
        if not force and not self.is_table_stale('bronze', table_name):
            logger.info(f"Table {table_name} is fresh, skipping extraction")
            return
        
        logger.info(f"Extracting table: {full_table_name}")
        
        # Build connection string
        conn_str = self._build_connection_string(source_config)
        
        try:
            # Connect and extract
            engine = create_engine(conn_str)
            
            query = table_config.get('query', f"SELECT * FROM {full_table_name}")
            df = pd.read_sql(query, engine)
            
            logger.info(f"Extracted {len(df)} rows from {full_table_name}")
            
            # Prepare metadata
            metadata = {
                'source_table': full_table_name,
                'extraction_time': datetime.now().isoformat(),
                'row_count': len(df),
                'column_count': len(df.columns),
                'columns': list(df.columns),
                'layer': 'bronze',
                'description': table_config.get('description', f'Raw extract from {full_table_name}')
            }
            
            # Save to parquet with metadata
            output_path = self.data_dir / "bronze" / f"{table_name}.parquet"
            
            # Convert to PyArrow table for metadata embedding
            pa_table = pa.Table.from_pandas(df)
            pa_table = pa_table.replace_schema_metadata({
                'parquet_pipelines_metadata': json.dumps(metadata)
            })
            
            pq.write_table(pa_table, output_path)
            
            # Register in DuckLake
            conn = self._get_duck_connection()
            conn.execute(f"DROP TABLE IF EXISTS bronze.{table_name}")
            conn.execute(f"CREATE TABLE bronze.{table_name} AS SELECT * FROM '{output_path}'")
            
            logger.info(f"Saved to {output_path} and registered in DuckLake")
            
        except Exception as e:
            logger.error(f"Failed to extract table {full_table_name}: {e}")
            raise
    
    def _resolve_env_vars(self, value):
        """Resolve environment variables in a string value like ${VAR}."""
        import re, os
        if isinstance(value, str):
            pattern = re.compile(r'\$\{([^}]+)\}')
            def replacer(match):
                return os.environ.get(match.group(1), match.group(0))
            return pattern.sub(replacer, value)
        return value

    def _build_connection_string(self, source_config: Dict) -> str:
        """Build database connection string from configuration."""
        connection = source_config.get('connection', {})
        db_type = self._resolve_env_vars(connection.get('type', 'mssql'))
        
        if db_type == 'mssql':
            server = self._resolve_env_vars(connection['server'])
            database = self._resolve_env_vars(connection['database'])
            if connection.get('trusted_connection', True):
                return f"mssql+pyodbc://{server}/{database}?driver=ODBC+Driver+17+for+SQL+Server&trusted_connection=yes"
            else:
                username = self._resolve_env_vars(connection['username'])
                password = self._resolve_env_vars(connection['password'])
                return f"mssql+pyodbc://{username}:{password}@{server}/{database}?driver=ODBC+Driver+17+for+SQL+Server"
        else:
            raise ValueError(f"Unsupported database type: {db_type}")
    
    def execute_sql_transformation(self, sql_file_path: Path, layer: str):
        """Execute a SQL transformation file."""
        if not sql_file_path.exists():
            raise FileNotFoundError(f"SQL file not found: {sql_file_path}")
        
        with open(sql_file_path, 'r') as f:
            content = f.read()
        
        # Parse metadata header
        metadata = self._parse_sql_metadata(content)
        table_name = metadata.get('name', sql_file_path.stem)
        
        logger.info(f"Executing {layer} transformation: {table_name}")
        
        # Execute SQL
        conn = self._get_duck_connection()
        
        try:
            # Execute the SQL (should contain CREATE OR REPLACE TABLE statement)
            conn.execute(content)
            
            # Export to parquet
            output_path = self.data_dir / layer / f"{table_name}.parquet"
            conn.execute(f"COPY {layer}.{table_name} TO '{output_path}' (FORMAT PARQUET)")
            
            # Update metadata
            metadata.update({
                'execution_time': datetime.now().isoformat(),
                'layer': layer,
                'output_path': str(output_path)
            })
            
            logger.info(f"Completed transformation: {table_name} -> {output_path}")
            
        except Exception as e:
            logger.error(f"Failed to execute SQL transformation {sql_file_path}: {e}")
            raise
    
    def _parse_sql_metadata(self, sql_content: str) -> Dict[str, Any]:
        """Parse metadata header from SQL file."""
        metadata = {}
        lines = sql_content.split('\n')
        
        for line in lines:
            line = line.strip()
            if line.startswith('--') and ':' in line:
                # Parse metadata line: -- key: value
                parts = line[2:].strip().split(':', 1)
                if len(parts) == 2:
                    key = parts[0].strip()
                    value = parts[1].strip()
                    metadata[key] = value
            elif not line.startswith('--') and line:
                # End of header comments
                break
        
        return metadata
    
    def run_pipeline(self, pipeline_config: Dict):
        """Execute a complete pipeline."""
        logger.info(f"Starting pipeline: {pipeline_config.get('name', 'unnamed')}")
        
        # Execute transformation steps in order
        for step in pipeline_config.get('steps', []):
            if step.startswith('sql/silver/'):
                sql_path = self.base_dir / step
                self.execute_sql_transformation(sql_path, 'silver')
            elif step.startswith('sql/gold/'):
                sql_path = self.base_dir / step
                self.execute_sql_transformation(sql_path, 'gold')
            else:
                logger.warning(f"Unknown step type: {step}")
        
        logger.info("Pipeline completed successfully")
    
    def run_named_pipeline(self, pipeline_name: str):
        """Execute a named pipeline."""
        named_pipelines = self.load_config('named_pipelines')
        
        if pipeline_name not in named_pipelines:
            raise ValueError(f"Named pipeline '{pipeline_name}' not found")
        
        pipeline_config = named_pipelines[pipeline_name]
        logger.info(f"Running named pipeline: {pipeline_name}")
        logger.info(f"Description: {pipeline_config.get('description', 'No description')}")
        
        # Extract required tables if needed
        if 'extract' in pipeline_config:
            source_config = self.load_config('source_tables')
            extract_config = pipeline_config['extract']
            
            for table_name in extract_config.get('tables', []):
                # Find table config
                table_config = None
                for table in source_config.get('tables', []):
                    if table['name'] == table_name.split('.')[-1]:  # Handle schema.table format
                        table_config = table
                        break
                
                if table_config:
                    self.extract_table(source_config, table_config)
                else:
                    logger.warning(f"Table configuration not found for: {table_name}")
        
        # Run transformation steps
        if 'transform' in pipeline_config:
            self.run_pipeline(pipeline_config['transform'])
    
    def init_project(self):
        """Initialize a new Parquet Pipelines project."""
        logger.info("Initializing new Parquet Pipelines project...")
        
        # Create example configurations
        self._create_example_configs()
        self._create_example_sql()
        self._create_gitignore()
        self._create_readme()
        
        logger.info("Project initialized successfully!")
        logger.info("Next steps:")
        logger.info("1. Edit config/source_tables.yml with your database connection")
        logger.info("2. Run: python -m parquet_pipelines extract --all")
        logger.info("3. Create SQL transformations in sql/silver/ and sql/gold/")
        logger.info("4. Run: python -m parquet_pipelines run --pipeline main")
    
    def _create_example_configs(self):
        """Create example configuration files."""
        
        # Source tables config
        source_config = {
            'connection': {
                'type': 'mssql',
                'server': 'localhost\\SQLEXPRESS',
                'database': 'YourDatabase',
                'trusted_connection': True
            },
            'tables': [
                {
                    'name': 'customers',
                    'schema': 'dbo',
                    'description': 'Customer master data',
                    'query': 'SELECT * FROM dbo.customers'
                },
                {
                    'name': 'orders',
                    'schema': 'dbo', 
                    'description': 'Order transactions',
                    'query': 'SELECT * FROM dbo.orders'
                }
            ]
        }
        
        with open(self.config_dir / 'source_tables.yml', 'w') as f:
            yaml.dump(source_config, f, default_flow_style=False)
        
        # Main pipeline config
        pipeline_config = {
            'name': 'main',
            'description': 'Main transformation pipeline',
            'steps': [
                'sql/silver/customers_cleaned.sql',
                'sql/silver/orders_cleaned.sql',
                'sql/gold/fact_sales.sql',
                'sql/gold/dim_customers.sql'
            ]
        }
        
        with open(self.config_dir / 'pipeline.yml', 'w') as f:
            yaml.dump(pipeline_config, f, default_flow_style=False)
        
        # Named pipelines config
        named_pipelines = {
            'daily_refresh': {
                'description': 'Daily data refresh for reporting',
                'extract': {
                    'tables': ['dbo.customers', 'dbo.orders'],
                    'only_if': {
                        'last_updated': '<TODAY'
                    }
                },
                'transform': {
                    'steps': [
                        'sql/silver/customers_cleaned.sql',
                        'sql/gold/dim_customers.sql'
                    ]
                }
            }
        }
        
        with open(self.config_dir / 'named_pipelines.yml', 'w') as f:
            yaml.dump(named_pipelines, f, default_flow_style=False)
    
    def _create_example_sql(self):
        """Create example SQL transformation files."""
        
        # Silver layer example
        silver_sql = """-- name: customers_cleaned
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
"""
        
        with open(self.sql_dir / 'silver' / 'customers_cleaned.sql', 'w') as f:
            f.write(silver_sql)
        
        # Gold layer example
        gold_sql = """-- name: dim_customers
-- layer: gold
-- description: Customer dimension table for analytics
-- depends_on: silver.customers_cleaned

CREATE OR REPLACE TABLE gold.dim_customers AS
SELECT 
    customer_id,
    first_name,
    last_name,
    full_name || ' (' || email || ')' AS customer_display_name,
    email,
    phone,
    address,
    city,
    state,
    zip_code,
    DATE_TRUNC('month', created_date) AS signup_month,
    DATEDIFF('day', created_date, CURRENT_DATE) AS days_since_signup,
    CASE 
        WHEN DATEDIFF('day', created_date, CURRENT_DATE) <= 30 THEN 'New'
        WHEN DATEDIFF('day', created_date, CURRENT_DATE) <= 365 THEN 'Active'
        ELSE 'Veteran'
    END AS customer_segment
FROM silver.customers_cleaned;
"""
        
        with open(self.sql_dir / 'gold' / 'dim_customers.sql', 'w') as f:
            f.write(gold_sql)
    
    def _create_gitignore(self):
        """Create .gitignore file to exclude data directory."""
        gitignore_content = """# Parquet Pipelines - Exclude data and database files
/data/
*.duckdb
*.duckdb.wal

# Python
__pycache__/
*.py[cod]
*$py.class
*.so
.Python
env/
venv/
.venv/
.env

# IDE
.vscode/
.idea/
*.swp
*.swo

# OS
.DS_Store
Thumbs.db
"""
        
        with open(self.base_dir / '.gitignore', 'w') as f:
            f.write(gitignore_content)
    
    def _create_readme(self):
        """Create README.md file."""
        readme_content = """# Parquet Pipelines

A minimal, SQL-first data transformation framework for teams migrating from stored procedures to modern analytics.

## Quick Start

1. **Initialize project** (if not already done):
   ```bash
   python -m parquet_pipelines init
   ```

2. **Configure your database connection**:
   Edit `config/source_tables.yml` with your database details.

3. **Extract data**:
   ```bash
   # Extract all configured tables
   python -m parquet_pipelines extract --all
   
   # Extract specific table
   python -m parquet_pipelines extract --table customers
   ```

4. **Run transformations**:
   ```bash
   # Run main pipeline
   python -m parquet_pipelines run --pipeline main
   
   # Run named pipeline
   python -m parquet_pipelines run --named daily_refresh
   ```

## Directory Structure

```
├── config/
│   ├── source_tables.yml      # Database connection and table definitions
│   ├── pipeline.yml           # Main transformation pipeline
│   └── named_pipelines.yml    # Named, reusable pipelines
├── sql/
│   ├── silver/               # Data cleaning transformations
│   └── gold/                 # Business logic transformations
├── data/                     # Generated data files (gitignored)
│   ├── bronze/              # Raw extracted data
│   ├── silver/              # Cleaned data
│   └── gold/                # Analytics-ready data
└── ducklake_meta.duckdb     # DuckLake catalog metadata
```

## SQL File Format

All SQL files must include a metadata header:

```sql
-- name: table_name
-- layer: silver|gold
-- description: What this transformation does
-- depends_on: bronze.source_table

CREATE OR REPLACE TABLE silver.table_name AS
SELECT ...
```

## Commands

- `init`: Initialize new project with example configs
- `extract`: Extract data from source systems to bronze layer
- `run`: Execute transformation pipelines
- `status`: Show pipeline status and table freshness

## Features

- ✅ SQL-first transformations
- ✅ Automatic dependency management
- ✅ Embedded metadata in output files
- ✅ DuckLake integration for queryable catalog
- ✅ Portable across Windows/Docker/Cloud
- ✅ No external orchestration required
- ✅ Power BI ready outputs
"""
        
        with open(self.base_dir / 'README.md', 'w') as f:
            f.write(readme_content)


def main():
    """CLI entry point."""
    parser = argparse.ArgumentParser(description='Parquet Pipelines - SQL-first data transformation framework')
    subparsers = parser.add_subparsers(dest='command', help='Available commands')
    
    # Init command
    subparsers.add_parser('init', help='Initialize new Parquet Pipelines project')
    
    # Extract command
    extract_parser = subparsers.add_parser('extract', help='Extract data from source systems')
    extract_parser.add_argument('--all', action='store_true', help='Extract all configured tables')
    extract_parser.add_argument('--table', help='Extract specific table')
    extract_parser.add_argument('--force', action='store_true', help='Force extraction even if data is fresh')
    
    # Run command
    run_parser = subparsers.add_parser('run', help='Run transformation pipelines')
    run_parser.add_argument('--pipeline', help='Run pipeline from pipeline.yml')
    run_parser.add_argument('--named', help='Run named pipeline')
    
    # Status command
    subparsers.add_parser('status', help='Show pipeline status')
    
    args = parser.parse_args()
    
    if not args.command:
        parser.print_help()
        return
    
    # Initialize framework
    pp = ParquetPipelines()
    
    try:
        if args.command == 'init':
            pp.init_project()
            
        elif args.command == 'extract':
            source_config = pp.load_config('source_tables')
            
            if args.all:
                for table_config in source_config.get('tables', []):
                    pp.extract_table(source_config, table_config, force=args.force)
            elif args.table:
                table_config = None
                for table in source_config.get('tables', []):
                    if table['name'] == args.table:
                        table_config = table
                        break
                
                if table_config:
                    pp.extract_table(source_config, table_config, force=args.force)
                else:
                    logger.error(f"Table '{args.table}' not found in configuration")
                    return 1
            else:
                logger.error("Must specify --all or --table")
                return 1
                
        elif args.command == 'run':
            if args.pipeline:
                pipeline_config = pp.load_config('pipeline')
                pp.run_pipeline(pipeline_config)
            elif args.named:
                pp.run_named_pipeline(args.named)
            else:
                logger.error("Must specify --pipeline or --named")
                return 1
                
        elif args.command == 'status':
            # TODO: Implement status command
            logger.info("Status command not yet implemented")
            
    except Exception as e:
        logger.error(f"Command failed: {e}")
        return 1
    
    return 0


if __name__ == '__main__':
    sys.exit(main())
