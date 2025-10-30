# Cost Estimation

### Below is an approximate monthly cost breakdown for running the data pipeline on Azure:

| **Resource** | **Tier** | **Approx. Monthly Cost (USD)** | **Description** |
|---------------|-----------|-------------------------------:|------------------|
| **App Service Plan** | Premium v3 P0V3 | ~$65 | Runs the containerized web application. |
| **Azure Container Registry (ACR)** | Standard | ~$20 | Stores the Docker image used for deployment. Includes 100 GB of free storage. |
| **Azure File Share Storage** | StorageV2 (general purpose v2) | ~$3.4 | If database grows with 0.5 GB/day and append storage for 6 months. 
| **Azure Container Instance** | Linux Standard (SKU) | ~$48 | Dagster Container for automated ingestion and materializing of data into tables. 
| **Resource Group + Terraform Infrastructure** | – | Free | No cost for resource management or Terraform configuration itself. |

## **Total estimated cost: approximately $136/month**  

---
### App Service Plan
<img src = "assets/App Service Plan.png" width=700 height=300>

We have been using Basic 1 & 2 for testing. 
The cost estimation is based on the lowest premium version. 
As displayed there are different options to scale up/down based on the workload.

### Storage in Azure File Share

| Scenario        | Growth/day | 6-month size | Approx monthly avg | Cost/month (USD) |
| --------------- | ---------- | ------------ | ------------------ | ---------------- |
| Slow growth     | 0.5 GB/day | 90 GB        | 45 GB              | **$3.38 / mo**   |
| Moderate growth | 1 GB/day   | 180 GB       | 90 GB              | **$6.75 / mo**   |
| Fast growth     | 2 GB/day   | 360 GB       | 180 GB             | **$13.50 / mo**  |

*Based on appending data storage once a day and keep data for 6 months with RA-GRS Standard HDD pricing ($0.075/GB/month)*

There is a lot of consideration regarding storage. 
It is important to decide how to setup everything - if you want snapshots, backup, transactions etc. 
A consideration is also to move old data to Archive for cheaper long-term storage or decide to not store historical data at all.


### Container Instance (ACI)
<img src = "assets/Container Instance Cost Estimation.png" width=700 height=150>

Above you can see the daily cost for running the container. 
The container instance materializes the data with Dagster to the database for storage. 
The process in Dagster runs automatically with scheduling and sensors. 

### Container Registry (ACR)
<img src = "assets/ACR.png" width=600 Heigh=150>

As you can see above our standard Tier gives us 100 GiB, and we have used 3.82 GiB by spinning up our two containers. 
This means that if we don't exceed the 100 GiB limit, no extra cost apply.
The pricing plan Standard is recommended for app production. 

---
# Snowflake comparison

<img src = "assets/Snowflake Credit Cost.png" width=700 height=250>


| **Resource** | **Tier / Assumption** | **Approx. Monthly Cost (USD)** | **Description** |
| ------------ | --------------------- | ------------------------------ | --------------- |
| App Service Plan | Premium v3 P0V3 | ~$65 | Runs the containerized web application / dashboard 24/7. |
| Azure Container Registry (ACR) | Standard | ~$20 | Stores Docker image used for deployment. Includes 100 GB free. |
| Azure File Share Storage | StorageV2 (general purpose v2), 180 GB/month | ~$12 | Dashboard data or cached ETL results.                          |
| Azure Container Instance (Dagster) | Linux Standard (SKU) | ~$48 | Orchestrates pipeline and schedules ETL jobs. |
| Resource Group + Terraform Infrastructure | – | Free | No direct cost. |
| Snowflake Compute (ETL) | Small warehouse, 2 credits/hr × 0.25 hr/day × 30 days × $3.90/credit | $58.50 | Dagster ETL runs 15 min/day. |
| Snowflake Storage | 180 GB | $4.14 | Snowflake storage cost. |

## **Total Estimated Monthly Cost: ≈ $218 / month**

- Replacing DuckDB with Snowflake for ETL slightly increases monthly costs ($82/month) but eliminates local database management and allows scalable cloud ETL.

- Since the data only updates once a day the dashboard can run fully on Azure, using cached or static data which means we only use Snowflake compute for 15 minutes per day.

- On premise managing is not needed, Snowflake handles it.