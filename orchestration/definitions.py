# ==================== #
#       imports        #
# ==================== #
from pathlib import Path
import sys
import dlt
import dagster as dg
from dagster_dlt import DagsterDltResource, dlt_assets

# Säkerställ projektmoduler i PYTHONPATH
PROJECT_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(PROJECT_ROOT))

# dlt-källan
from data_extract_load.load_job_ads import jobads_source

# ==================== #
#   data warehouse     #
# ==================== #
db_path = str(PROJECT_ROOT / "data_warehouse" / "job_ads.duckdb")

# ==================== #
#       dlt Asset      #
# ==================== #
QUERY = ""
OCCUPATION_FIELDS = [
    "j7Cq_ZJe_GkT",   # Bygg och anläggning
    "9puE_nYg_crq",   # Kultur, media, design
    "MVqp_eS8_kDZ",   # Pedagogik
]
LIMIT = 100

dlt_resource = DagsterDltResource()

@dlt_assets(
    dlt_source=jobads_source(query=QUERY, occupation_fields=OCCUPATION_FIELDS, limit=LIMIT),
    dlt_pipeline=dlt.pipeline(
        pipeline_name="jobsearch",
        dataset_name="staging",
        destination=dlt.destinations.duckdb(db_path),
    ),
)
def dlt_load(context: dg.AssetExecutionContext, dlt: DagsterDltResource):
    """Kör dlt-load för alla resurser från jobads_source (en per occupation-field)."""
    yield from dlt.run(context=context)

# ==================== #
#       dbt Assets     #
# ==================== #
dbt_assets_list = []
resources = {"dlt": dlt_resource}

try:
    from dagster_dbt import DbtCliResource, DbtProject, dbt_assets

    dbt_project_directory = PROJECT_ROOT / "data_transformation"
    profiles_dir = Path.home() / ".dbt"

    dbt_project = DbtProject(project_dir=dbt_project_directory, profiles_dir=profiles_dir)
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
job_dlt = dg.define_asset_job(
    "job_dlt",
    selection=dg.AssetSelection.key_prefixes("dlt_jobads_source"),
)

jobs = [job_dlt]

if dbt_assets_list:
    job_dbt = dg.define_asset_job(
        "job_dbt",
        selection=dg.AssetSelection.key_prefixes("warehouse", "marts"),
    )
    jobs.append(job_dbt)

# ==================== #
#       Schedule       #
# ==================== #
schedule_dlt = dg.ScheduleDefinition(
    job=job_dlt,
    cron_schedule="25 11 * * *"  # UTC
)

# ==================== #
#        Sensors       #
# ==================== #
sensors = []

if 'dbt' in resources:
    # Skapa en unik asset-sensor per dlt-asset
    for of_code in OCCUPATION_FIELDS:
        asset_key_str = f"dlt_jobads_source_jobads_{of_code}"
        sensor_name = f"sensor_dbt_on_{of_code}"

        # Använd name= för att undvika dubbletter och binda värden via default-args
        def _make_sensor(asset_key_val: str, name_val: str):
            @dg.asset_sensor(asset_key=dg.AssetKey(asset_key_val), job_name="job_dbt", name=name_val)
            def sensor():
                yield dg.RunRequest()
            return sensor

        sensors.append(_make_sensor(asset_key_str, sensor_name))

# ==================== #
#     Definitions      #
# ==================== #
assets = [dlt_load, *dbt_assets_list]

defs = dg.Definitions(
    assets=assets,
    resources=resources,
    jobs=jobs,
    schedules=[schedule_dlt],
    sensors=sensors,
)