import dlt
import requests
import json
from pathlib import Path
import os

# Optional config tweak (truncate staging if reloading)
#dlt.config["load.truncate_staging_dataset"] = True


def _get_ads(url_for_search, params):
    headers = {"accept": "application/json"}
    response = requests.get(url_for_search, headers=headers, params=params, timeout=60)
    response.raise_for_status()
    return json.loads(response.content.decode("utf8"))


@dlt.resource(
    table_name="project_job_ads",  # raw table for dbt
    write_disposition="append",
)
def jobsearch_resource(params):
    """
    params ska minst innehålla:
      - "q": din query (kan vara tom sträng)
      - "limit": sidstorlek (t.ex. 100)
    """
    url = "https://jobsearch.api.jobtechdev.se"
    url_for_search = f"{url}/search"
    limit = params.get("limit", 100)
    offset = 0

# paginates through the Jobtech API results — meaning it fetches all available ads, not just the first page.
    while True:
        page_params = dict(params, offset=offset)
        data = _get_ads(url_for_search, page_params)

        hits = data.get("hits", [])
        if not hits:
            break

        for ad in hits:
            yield ad

        if len(hits) < limit or offset > 1900:
            break

        offset += limit


def run_pipeline(query, table_name, occupation_fields, duckdb_path="data_warehouse/job_ads.duckdb"):
    Path(duckdb_path).parent.mkdir(parents=True, exist_ok=True)

    # ✅ Updated DLT syntax — no more `credentials`
    pipeline = dlt.pipeline(
        pipeline_name="job_ads",
        destination=dlt.destinations.duckdb(duckdb_path),
        dataset_name="staging",
    )

    for occupation_field in occupation_fields:
        params = {"q": query, "limit": 100, "occupation-field": occupation_field}
        load_info = pipeline.run(
            jobsearch_resource(params=params)
        )
        print(f"✅ Loaded occupation field: {occupation_field}")
        print(load_info)


@dlt.source
def jobads_source(query: str, occupation_fields: list[str], limit: int = 100):
    for of in occupation_fields:
        yield jobsearch_resource(
            params={"q": query, "limit": limit, "occupation-field": of}
        ).with_name(f"jobads_{of}")  # namnger asset, inte DB-tabell


if __name__ == "__main__":
    working_directory = Path(__file__).parent
    os.chdir(working_directory)

    query = ""
    table_name = "project_job_ads"
    occupation_fields = ("j7Cq_ZJe_GkT", "9puE_nYg_crq", "MVqp_eS8_kDZ")

    run_pipeline(query, table_name, occupation_fields, duckdb_path="data_warehouse/job_ads.duckdb")
