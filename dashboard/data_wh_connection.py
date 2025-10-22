from pathlib import Path
import duckdb
import os

# data warehouse directory
DB_PATH = os.getenv("DUCKDB_PATH")

def query_job_table(table_name):
    query = f"SELECT * FROM {table_name}"
    with duckdb.connect(DB_PATH, read_only=True) as conn:
        return conn.query(f"{query}").df()

