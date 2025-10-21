# Data Pipeline Documentation

## Overview
This project implements a data pipeline for job advertisements processing, utilizing various technologies and components organized in a modular structure.

## Pipeline Components

### 1. Data Extraction and Loading (`data_extract_load/`)
- Entry point: `load_job_ads.py`
- Purpose: Handles the initial data extraction and loading of job advertisements
- Connection: Feeds data into the DuckDB data warehouse (`data_warehouse/job_ads.duckdb`)

### 2. Data Warehouse (`data_warehouse/`)
- Storage: Uses DuckDB (`job_ads.duckdb`)
- Purpose: Serves as the primary storage for raw job advertisements data
- Connection: Acts as a source for dbt transformations and dashboard queries

### 3. Data Transformation (`data_transformation/`)
The transformation layer uses dbt (data build tool) with the following model structure:

#### Source Layer (`models/src/`)
- Raw data ingestion
- Files:
  - `sources.yml`: Defines data sources
  - Source models for various entities (job ads, employer, occupation, etc.)

#### Dimensional Models (`models/dim/`)
- Creates dimensional tables for:
  - Auxiliary attributes
  - Employer information
  - Job details
  - Occupation data

#### Fact Tables (`models/fct/`)
- `fct_job_ads.sql`: Main fact table for job advertisements

#### Mart Layer (`models/mart/`)
Specialized marts for different sectors:
- Building sector (`marts_bygg.sql`)
- Cultural sector (`marts_kultur.sql`)
- Pedagogical sector (`marts_pedagogik.sql`)

### 4. Dashboard (`dashboard/`)
- Main file: `dashboard.py`
- Database connection: `data_wh_connection.py`
- Purpose: Visualizes the processed data
- Connection: Reads from the transformed data in the data warehouse

### 5. Orchestration (`orchestration/`)
- Contains pipeline definitions and scheduling logic
- File: `definitions.py`

## Data Flow

1. Data Extraction → Raw data is extracted using `load_job_ads.py`
2. Storage → Data is stored in DuckDB warehouse
3. Transformation → dbt models process the data in layers:
   - Source → Dimensions → Facts → Marts
4. Visualization → Dashboard queries the transformed data

## Dependencies
- Requirements are split for different operating systems:
  - `requirements_mac.txt`
  - `requirements_windows.txt`

