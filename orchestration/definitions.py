# ==================== #
#       imports        #
# ==================== #
from pathlib import Path
import sys
import os
import dagster as dg
from dagster_dbt import DbtCliResource, DbtProject, dbt_assets

# Säkerställ projektmoduler i PYTHONPATH
PROJECT_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(PROJECT_ROOT))

# Import your ingestion pipeline
from data_extract_load.load_job_ads import run_pipeline

# to import dlt script
sys.path.insert(0, '../data_extract_load')
from data_extract_load.load_job_ads import jobads_source

# Paths
DUCKDB_PATH = os.getenv("DUCKDB_PATH")
DBT_PROFILES_DIR = os.getenv("DBT_PROFILES_DIR")

# ==================== #
#   data warehouse     #
# ==================== #
db_path = str(PROJECT_ROOT / "data_warehouse" / "job_ads.duckdb")

# ==================== #
#     Ingestion Asset  #
# ==================== #
@dg.asset
def load_job_ads_to_duckdb():
    """Extracts and loads job ads data into DuckDB."""
    query = ""
    table_name = "project_job_ads"
    occupation_fields = ["j7Cq_ZJe_GkT", "9puE_nYg_crq", "MVqp_eS8_kDZ"]

    run_pipeline(query, table_name, occupation_fields, duckdb_path=db_path)
    return "Job ads successfully loaded into DuckDB"


# ==================== #
#       dbt Assets     #
# ==================== #
dbt_assets_list = []
resources = {}

try:
    dbt_project_directory = PROJECT_ROOT / "data_transformation"
    profiles_dir = Path.home() / ".dbt"

    dbt_project = DbtProject(project_dir=dbt_project_directory,
                        profiles_dir=Path(DBT_PROFILES_DIR))
    dbt_resource = DbtCliResource(project_dir=dbt_project)
    dbt_project.prepare_if_dev()

    @dbt_assets(manifest=dbt_project.manifest_path)
    def dbt_models(context: dg.AssetExecutionContext, dbt: DbtCliResource):
        yield from dbt.cli(["build"], context=context).stream()

    dbt_assets_list = [dbt_models]
    resources["dbt"] = dbt_resource

except Exception as e:
    dg.get_dagster_logger().warning(f"DBT disabled: {e}")


# ==================== #
#         Jobs         #
# ==================== #
job_ingestion = dg.define_asset_job(
    "job_ingestion",
    selection=dg.AssetSelection.assets(load_job_ads_to_duckdb),
)

jobs = [job_ingestion]

if dbt_assets_list:
    job_dbt = dg.define_asset_job(
        "job_dbt",
        selection=dg.AssetSelection.key_prefixes("warehouse", "marts"),
    )
    jobs.append(job_dbt)

# ==================== #
#       Schedule       #
# ==================== #
schedule_ingestion = dg.ScheduleDefinition(
    job=job_ingestion,
    cron_schedule="25 11 * * *"  # UTC
)

# ==================== #
#     Definitions      #
# ==================== #
assets = [load_job_ads_to_duckdb, *dbt_assets_list]

defs = dg.Definitions(
    assets=assets,
    resources=resources,
    jobs=jobs,
    schedules=[schedule_ingestion],
)
