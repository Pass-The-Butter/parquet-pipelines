#!/usr/bin/env python3
"""
Parquet Pipelines CLI Application with Proper DuckLake Integration
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
    """Main application class for Parquet Pipelines framework with DuckLake integration."""
    
    def __init__(self, base_dir: Path = None):
        """Initialize the pipeline framework."""
        self.base_dir = base_dir or Path.cwd()
        self.data_dir = self.base_dir / "data"
        self.config_dir = self.base_dir / "config"
        self.sql_dir = self.base_dir / "sql"
        self.scripts_dir = self.base_dir / "scripts"
        
        # DuckLake configuration
        self.ducklake_catalog = self.base_dir / "ducklake_catalog.duckdb"
        self.ducklake_data_path = self.data_dir / "ducklake_files"
        self.ducklake_name = "parquet_pipelines"
        self.duck_conn = None
        
        # Ensure directory structure exists
        self._ensure_directory_structure()
        
    def _ensure_directory_structure(self):
        """Create required directory structure if it doesn't exist."""
        directories = [
            self.data_dir / "bronze",  # Keep for compatibility
            self.data_dir / "silver", 
            self.data_dir / "gold",
            self.ducklake_data_path,  # DuckLake data files
            self.config_dir,
            self.sql_dir / "silver",
            self.sql_dir / "gold",
            self.scripts_dir
        ]
        
        for directory in directories:
            directory.mkdir(parents=True, exist_ok=True)
            logger.info(f"Ensured directory exists: {directory}")
    
    def _get_duck_connection(self):
        """Get or create DuckDB connection with DuckLake properly configured."""
        if self.duck_conn is None:
            # Create connection to catalog database
            self.duck_conn = duckdb.connect(str(self.ducklake_catalog))
            
            # Install and load DuckLake extension
            logger.info("Installing DuckLake extension...")
            self.duck_conn.execute("INSTALL ducklake")
            self.duck_conn.execute("LOAD ducklake")
            
            # Check if DuckLake is already attached
            attached_dbs = self.duck_conn.execute("SHOW DATABASES").fetchall()
            ducklake_attached = any(db[0] == self.ducklake_name for db in attached_dbs)
            
            if not ducklake_attached:
                # Attach or create DuckLake with proper syntax
                ducklake_path = f"ducklake:{self.ducklake_catalog}"
                data_path = str(self.ducklake_data_path)
                
                try:
                    # Try to attach existing DuckLake
                    self.duck_conn.execute(f"ATTACH '{ducklake_path}' AS {self.ducklake_name}")
                    logger.info(f"Attached existing DuckLake: {self.ducklake_name}")
                except:
                    # Create new DuckLake
                    self.duck_conn.execute(
                        f"ATTACH '{ducklake_path}' AS {self.ducklake_name} (DATA_PATH '{data_path}/')"
                    )
                    logger.info(f"Created new DuckLake: {self.ducklake_name} with data path: {data_path}")
            
            # Use the DuckLake as default database
            self.duck_conn.execute(f"USE {self.ducklake_name}")
            
            # Create schemas within DuckLake if they don't exist
            self.duck_conn.execute("CREATE SCHEMA IF NOT EXISTS bronze")
            self.duck_conn.execute("CREATE SCHEMA IF NOT EXISTS silver") 
            self.duck_conn.execute("CREATE SCHEMA IF NOT EXISTS gold")
            
            logger.info(f"Connected to DuckLake: {self.ducklake_name}")
            
        return self.duck_conn
    
    def get_table_metadata(self, schema: str, table_name: str) -> Optional[Dict]:
        """Get table metadata from DuckLake catalog."""
        conn = self._get_duck_connection()
        try:
            # Query DuckLake metadata tables
            result = conn.execute(f"""
                SELECT 
                    t.table_id,
                    t.table_name,
                    s.record_count,
                    s.file_size_bytes,
                    s.next_row_id
                FROM ducklake_table t
                LEFT JOIN ducklake_table_stats s ON t.table_id = s.table_id
                WHERE t.table_name = '{table_name}'
                AND t.schema_id = (
                    SELECT schema_id FROM ducklake_schema 
                    WHERE schema_name = '{schema}' 
                    AND end_snapshot IS NULL
                )
                AND t.end_snapshot IS NULL
            """).fetchone()
            
            if result:
                return {
                    'exists': True,
                    'table_id': result[0],
                    'table_name': result[1],
                    'record_count': result[2] or 0,
                    'file_size_bytes': result[3] or 0,
                    'next_row_id': result[4] or 0
                }
        except Exception as e:
            logger.debug(f"Table {schema}.{table_name} not found in DuckLake catalog: {e}")
        
        return None
    
    def is_table_stale(self, schema: str, table_name: str, max_age_hours: int = 24) -> bool:
        """Check if a table needs refreshing based on DuckLake snapshots."""
        metadata = self.get_table_metadata(schema, table_name)
        if not metadata:
            return True  # Table doesn't exist, needs extraction
        
        conn = self._get_duck_connection()
        
        # Check last snapshot time for this table
        try:
            result = conn.execute(f"""
                SELECT MAX(s.snapshot_timestamp)
                FROM ducklake_snapshot s
                JOIN ducklake_snapshot_changes sc ON s.snapshot_id = sc.snapshot_id
                WHERE sc.snapshot_changes LIKE '%table:{metadata['table_id']}%'
            """).fetchone()
            
            if result and result[0]:
                last_update = result[0]
                if isinstance(last_update, str):
                    last_update = datetime.fromisoformat(last_update.replace('+00', ''))
                age = datetime.now() - last_update
                return age > timedelta(hours=max_age_hours)
        except Exception as e:
            logger.debug(f"Could not determine table staleness: {e}")
        
        return True
    
    def extract_table(self, source_config: Dict, table_config: Dict, force: bool = False):
        """Extract a single table from source to bronze layer using DuckLake."""
        table_name = table_config['name']
        schema = table_config.get('schema', 'dbo')
        full_table_name = f"{schema}.{table_name}"
        
        # Check if extraction is needed
        if not force and not self.is_table_stale('bronze', table_name):
            logger.info(f"Table {table_name} is fresh in DuckLake, skipping extraction")
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
            
            # Write to DuckLake using CREATE OR REPLACE TABLE
            conn = self._get_duck_connection()
            
            # Register DataFrame as temporary view
            conn.register('temp_extract', df)
            
            # Create or replace table in DuckLake
            conn.execute(f"""
                CREATE OR REPLACE TABLE bronze.{table_name} AS 
                SELECT * FROM temp_extract
            """)
            
            # Add comment with metadata
            conn.execute(f"""
                COMMENT ON TABLE bronze.{table_name} IS '{json.dumps(metadata)}'
            """)
            
            # Also export to Parquet for compatibility (optional)
            output_path = self.data_dir / "bronze" / f"{table_name}.parquet"
            pa_table = pa.Table.from_pandas(df)
            pa_table = pa_table.replace_schema_metadata({
                'parquet_pipelines_metadata': json.dumps(metadata)
            })
            pq.write_table(pa_table, output_path)
            
            logger.info(f"Saved to DuckLake bronze.{table_name} and {output_path}")
            
        except Exception as e:
            logger.error(f"Failed to extract table {full_table_name}: {e}")
            raise
    
    def execute_sql_transformation(self, sql_file_path: Path, layer: str):
        """Execute a SQL transformation file in DuckLake."""
        if not sql_file_path.exists():
            raise FileNotFoundError(f"SQL file not found: {sql_file_path}")
        
        with open(sql_file_path, 'r') as f:
            content = f.read()
        
        # Parse metadata header
        metadata = self._parse_sql_metadata(content)
        table_name = metadata.get('name', sql_file_path.stem)
        
        logger.info(f"Executing {layer} transformation: {table_name}")
        
        # Execute SQL in DuckLake
        conn = self._get_duck_connection()
        
        try:
            # Execute the SQL (should contain CREATE OR REPLACE TABLE statement)
            conn.execute(content)
            
            # Add comment with metadata
            if metadata:
                metadata['execution_time'] = datetime.now().isoformat()
                metadata['layer'] = layer
                conn.execute(f"""
                    COMMENT ON TABLE {layer}.{table_name} IS '{json.dumps(metadata)}'
                """)
            
            # Export to Parquet for compatibility (optional)
            output_path = self.data_dir / layer / f"{table_name}.parquet"
            conn.execute(f"""
                COPY {layer}.{table_name} TO '{output_path}' (FORMAT PARQUET)
            """)
            
            logger.info(f"Completed transformation: {table_name} in DuckLake and exported to {output_path}")
            
        except Exception as e:
            logger.error(f"Failed to execute SQL transformation {sql_file_path}: {e}")
            raise
    
    def query_ducklake(self, query: str):
        """Execute a query against DuckLake and return results."""
        conn = self._get_duck_connection()
        return conn.execute(query).fetchall()
    
    def get_ducklake_stats(self):
        """Get statistics about the DuckLake catalog."""
        conn = self._get_duck_connection()
        
        stats = {
            'snapshots': conn.execute("SELECT COUNT(*) FROM ducklake_snapshot").fetchone()[0],
            'schemas': conn.execute("SELECT COUNT(*) FROM ducklake_schema WHERE end_snapshot IS NULL").fetchone()[0],
            'tables': conn.execute("SELECT COUNT(*) FROM ducklake_table WHERE end_snapshot IS NULL").fetchone()[0],
            'data_files': conn.execute("SELECT COUNT(*) FROM ducklake_data_file").fetchone()[0],
            'total_size_bytes': conn.execute("SELECT SUM(file_size_bytes) FROM ducklake_data_file").fetchone()[0] or 0
        }
        
        # Get table details
        tables = conn.execute("""
            SELECT 
                s.schema_name,
                t.table_name,
                ts.record_count,
                ts.file_size_bytes
            FROM ducklake_table t
            JOIN ducklake_schema s ON t.schema_id = s.schema_id
            LEFT JOIN ducklake_table_stats ts ON t.table_id = ts.table_id
            WHERE t.end_snapshot IS NULL AND s.end_snapshot IS NULL
            ORDER BY s.schema_name, t.table_name
        """).fetchall()
        
        stats['tables_detail'] = [
            {
                'schema': t[0],
                'table': t[1],
                'rows': t[2] or 0,
                'size_bytes': t[3] or 0
            }
            for t in tables
        ]
        
        return stats
    
    def time_travel_query(self, table: str, version: Optional[int] = None, timestamp: Optional[str] = None):
        """Query a table at a specific version or timestamp using DuckLake time travel."""
        conn = self._get_duck_connection()
        
        if version is not None:
            query = f"SELECT * FROM {table} AT (VERSION => {version})"
        elif timestamp:
            query = f"SELECT * FROM {table} AT (TIMESTAMP => '{timestamp}')"
        else:
            query = f"SELECT * FROM {table}"
        
        return conn.execute(query).fetchdf()
    
    # ... (keep all other existing methods like _parse_sql_metadata, _build_connection_string, etc.)
    
    def cleanup(self):
        """Clean up resources and detach from DuckLake."""
        if self.duck_conn:
            try:
                # Switch to memory database before detaching
                self.duck_conn.execute("USE memory")
                # Detach DuckLake
                self.duck_conn.execute(f"DETACH {self.ducklake_name}")
                logger.info(f"Detached from DuckLake: {self.ducklake_name}")
            except:
                pass
            finally:
                self.duck_conn.close()
                self.duck_conn = None