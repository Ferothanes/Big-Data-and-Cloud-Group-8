// ...existing code...
# Data Pipeline Documentation

## Overview
This repository implements an end-to-end pipeline for collecting, storing, transforming and visualizing job advertisements. Components are organized into extraction, warehouse, transformation (dbt), orchestration (Dagster), dashboard (Streamlit) and deployment (Docker / Terraform).

## script summary

### Data Extraction & Loading (data_extract_load/)
  - load_job_ads.py — DLT pipeline entrypoint. Defines a source (jobads_source) and resource (jobsearch_resource), extraction logic, and run_pipeline() which executes the DLT pipeline and writes a DuckDB table named `project_job_ads`.
  - __init__.py — package exports and helper constants (exposes run_pipeline and resource defs for orchestration).
  - any helpers (if present) — small utilities for HTTP requests / parsing / retry logic used by the pipeline.

### Data Warehouse (data_warehouse/)
  - job_ads.duckdb — DuckDB file used at runtime. Holds raw ingestion table `project_job_ads` and the schemas/tables materialized by dbt (e.g., staging, dim, fct, marts).
  - (folder) — mounted as a volume in docker-compose so containers share the same DB file.

### Data Transformation (data_transformation/)
  - dbt_project.yml — dbt project configuration: project name, profile (`dbt_duckdb`), model materializations and schema naming conventions (src/staging/warehouse/marts).
  - models/src/sources.yml — dbt source definition mapping `job_ads.stg_ads` to the DuckDB table `project_job_ads`.
  - models/src/*.sql — source SQL models that select raw columns from the dbt source and normalize field names / basic parsing.
  - models/dim/*.sql — dimension models. Examples:
    - dim_employer.sql — builds employer dimension from source fields, deduplicates and normalizes employer attributes.
    - dim_occupation.sql — builds occupation dimension and normalizes occupation identifiers / names.
    - dim_job_details.sql — extracts job-specific attributes (dates, location, contract type).
    - dim_auxilliary_attributes.sql — parses and normalizes auxiliary lists/flags.
  - models/fct/fct_job_ads.sql — fact model. Joins source + dims, computes surrogate keys (via dbt_utils macro), calculates metrics (vacancies, relevance, deadlines) and outputs canonical fact rows.
  - models/mart/*.sql — mart models. Sector-specific filtered outputs:
    - marts_pedagogik.sql — mart for pedagogical occupations.
    - marts_kultur.sql — mart for cultural occupations.
    - marts_bygg.sql — mart for construction/building occupations.
    These read the fact table and apply business filters/aggregations for dashboard consumption.
  - macros/*.sql — helper macros used across models (string cleaning, schema generation, surrogate key generation).
  - packages.yml, package-lock.yml — declare and lock dbt dependencies (e.g., dbt_utils).

### Orchestration (orchestration/)
  - definitions.py — Dagster asset/job definitions and schedules. Creates an asset/job that calls data_extract_load.run_pipeline to populate DuckDB, configures a dbt DbtProject resource (using env DBT_PROFILES_DIR) and optionally exposes dbt_models asset to run `dbt build` as part of the pipeline or in a scheduled job.
  - (possible config files) — job schedules / resource bindings referenced by Dagster.

### Dashboard (dashboard/)
  - data_wh_connection.py — small DB helper that opens a read connection to DuckDB using environment variable DUCKDB_PATH and provides query_job_table(query_name, ...) used by the Streamlit app.
  - dashboard.py — Streamlit application. Reads mart tables (marts.marts_pedagogik, marts.marts_kultur, marts.marts_bygg) and renders KPIs, tables and charts. Uses DUCKDB_PATH and queries via data_wh_connection.

### Container & Local Dev
  - dockerfile.dwh — Dockerfile used to build the "dwh" image (ingestion + dbt). Sets environment vars (DBT_PROFILES_DIR, DUCKDB path), installs dependencies, and starts Dagster / pipeline tooling.
  - dockerfile.dashboard — Dockerfile for Streamlit dashboard image; sets DUCKDB_PATH and runs streamlit.
  - docker-compose.yml — local composition: mounts `${HOME}/.dbt/profiles.yml` to `/pipeline/profiles.yml` (so dbt has profiles), binds the data_warehouse folder as a volume so all services share the same DuckDB file.

### Infrastructure as Code (IaC/)
  - main.tf, providers.tf, variables.tf, resource-group.tf — Terraform definitions to provision Azure resources (ACR, App Service Plan, Web App). Expectation: build images, push to ACR, then update and deploy via IaC.

### Project docs & dependencies
  - README.md — high-level project notes, deployment hints and costs.
  - documentation.md — this file.
  - requirements_mac.txt / requirements_windows.txt — pinned Python packages for local development on each OS.

## How components correlate (flow and responsibilities)

1. Ingestion → Warehouse
   - data_extract_load.load_job_ads.run_pipeline() (invoked directly or via Dagster in orchestration/definitions.py) extracts job ads from external sources, transforms minimal fields, and writes them into DuckDB table `project_job_ads` inside data_warehouse/job_ads.duckdb.

2. Warehouse → Transformation (dbt)
   - dbt (data_transformation) uses a profile named `dbt_duckdb` (profiles.yml) to connect to the same DuckDB file.
   - models/src/ use `{{ source('job_ads','stg_ads') }}` which maps to the ingestion-created table `project_job_ads`. Source models perform normalization and prepare data for dimension/fact models.
   - models/dim/ produce canonical dimension tables; models/fct/ produce the primary fact table; models/mart/ produce business-facing, aggregated or filtered tables in schema `marts`.

3. Transformation → Dashboard
   - The Streamlit dashboard reads the mart tables from the same DuckDB file (schema `marts`) using DUCKDB_PATH. This keeps dashboard reads consistent with the latest dbt builds.

4. Orchestration ties the above together
   - orchestration/definitions.py defines Dagster jobs that can run ingestion, run dbt (`dbt_models` asset) and orchestrate schedules. Environment variables configured in Docker / CI ensure all pieces point to the same DUCKDB and dbt profiles.

5. Deployment
   - docker-compose (local) ensures profiles and DB file are shared between containers. For cloud deployment, images built using dockerfile.dwh and dockerfile.dashboard are pushed to ACR and deployed using the Terraform IaC.

## Operational checklist - practical steps to run

### Prerequisites
- Ensure Python and dbt (matching dbt version in packages.yml) are installed, or use the provided Docker images.
- Create a dbt profiles.yml with a profile named `dbt_duckdb` that points to a DuckDB file path. Typical location: %USERPROFILE%\.dbt\profiles.yml (Windows) or ~/.dbt/profiles.yml (Linux/macOS).

### Local run (no Docker)
1. Set env vars (PowerShell examples):
   - $env:DUCKDB_PATH = "c:\Users\milou\Documents\Git\Big-Data-and-Cloud-Group-8\data_warehouse\job_ads.duckdb"
   - $env:DBT_PROFILES_DIR = "$env:USERPROFILE\.dbt"
2. Run ingestion:
   - python -m data_extract_load.load_job_ads
   - or run the Dagster job in orchestration if configured.
3. Run dbt build:
   - cd data_transformation
   - dbt build --profiles-dir $env:DBT_PROFILES_DIR
4. Start dashboard:
   - cd repository root
   - streamlit run dashboard/dashboard.py
5. Verify:
   - Query raw: SELECT count(*) FROM project_job_ads;
   - Query mart: SELECT count(*) FROM marts.marts_pedagogik;

### Local run (Docker Compose)
1. Ensure %USERPROFILE%\.dbt\profiles.yml exists and is configured for profile `dbt_duckdb`.
2. docker-compose up --build
   - Service ordering: dwh service should run ingestion/dbt; dashboard exposes Streamlit.
3. Confirm that the data_warehouse volume is mounted and job_ads.duckdb is created.

### CI / Deployment notes
- Build images for dwh and dashboard, push to ACR.
- Update IaC variables with image names / tags, then terraform apply.
- Ensure App Service environment variables include DUCKDB_PATH and DBT_PROFILES_DIR (or include a profiles.yml in the image).

### Quick validation queries (examples)
- Raw table existence: SELECT name FROM sqlite_master; (DuckDB: PRAGMA show_tables;)
- Count raw rows: SELECT count(*) FROM project_job_ads;
- Count mart rows: SELECT count(*) FROM marts.marts_bygg;

### Troubleshooting pointers
- If dbt complains about missing profile: verify DBT_PROFILES_DIR and that profiles.yml contains profile `dbt_duckdb`.
- If dashboard shows empty marts: ensure dbt build completed successfully and targeted the same DuckDB file path.
- If multiple environments: confirm all services reference the same absolute path to job_ads.duckdb or a shared mounted volume.