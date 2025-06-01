# Test Python connection
import sqlalchemy

engine = sqlalchemy.create_engine('mssql+pyodbc://sa:Chocolate1!@Frank/SampleRetailDB?driver=ODBC+Driver+17+for+SQL+Server')

with engine.connect() as connection:
    result = connection.execute(sqlalchemy.text('SELECT COUNT(*) FROM dbo.customers')).fetchone()
    print(f'✅ Connection successful! Found {result[0]} customers')
# End of script