from pathlib import Path
import duckdb

# data warehouse directory
db_path = str(Path(__file__).parents[1] / "data_warehouse/jobads.duckdb")
 
def query_job_table(table_name):
    query = f"SELECT * FROM {table_name}"
    with duckdb.connect(db_path, read_only=True) as conn:
        return conn.query(f"{query}").df()

