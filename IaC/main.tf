# -------------------------------
# Terraform + Provider Setup
# -------------------------------
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0.2"
    }
  }
  required_version = ">= 1.1.0"
}

provider "azurerm" {
  features {}
}

# -------------------------------
# Resource Group
# -------------------------------
resource "azurerm_resource_group" "rg" {
  name     = "myTFResourceGroup"   # <<< change name if you want
  location = "swedencentral"
}

# -------------------------------
# Random suffix for unique resource names
# -------------------------------
resource "random_integer" "number" {
  min = 10000
  max = 99999
}

# -------------------------------
# Storage Account for DuckDB & DBT
# -------------------------------
resource "azurerm_storage_account" "storage" {
  name                     = "${var.prefix_app_name}storage${random_integer.number.result}"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_share" "file_share" {
  name                 = "data"
  storage_account_name = azurerm_storage_account.storage.name
  quota                = 50  # GB
}


# -------------------------------
# Azure Container Registry (ACR)
# -------------------------------
resource "azurerm_container_registry" "acr" {
  name                = "${var.prefix_app_name}acr${random_integer.number.result}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "Basic"   # <<< cheap tier
  admin_enabled       = true
}

# -------------------------------
# App Service Plan (Linux)
# -------------------------------
resource "azurerm_service_plan" "asp" {
  name                = "${var.prefix_app_name}-asp"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  os_type             = "Linux"
  sku_name            = "B1"  # <<< cheap dev/test tier
}

# -------------------------------
# Web App (Streamlit Dashboard)
# -------------------------------
resource "azurerm_linux_web_app" "dashboard" {
  name                = "${var.prefix_app_name}-dashboard-app"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  service_plan_id     = azurerm_service_plan.asp.id

  site_config {
    always_on = true
  }

  app_settings = {
    WEBSITES_PORT                   = "8501"
    DOCKER_REGISTRY_SERVER_URL      = "https://${azurerm_container_registry.acr.login_server}"
    DOCKER_REGISTRY_SERVER_USERNAME = azurerm_container_registry.acr.admin_username
    DOCKER_REGISTRY_SERVER_PASSWORD = azurerm_container_registry.acr.admin_password
    DOCKER_CUSTOM_IMAGE_NAME        = "${azurerm_container_registry.acr.login_server}/${var.prefix_app_name}-dashboard:latest"
  }
}

# -------------------------------
# Container Instance (DWH Pipeline)
# -------------------------------
resource "azurerm_container_group" "dwh_pipeline" {
  name                = "${var.prefix_app_name}-pipeline"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  os_type             = "Linux"
  ip_address_type     = "Public"
  dns_name_label      = "${var.prefix_app_name}-pipeline-${random_integer.number.result}"

  container {
    name   = "dwh-pipeline"
    image  = "${azurerm_container_registry.acr.login_server}/dwh_pipeline:latest"
    cpu    = "1"
    memory = "4"

    ports {
      port     = 80
      protocol = "TCP"
    }


    environment_variables = {
      DBT_PROFILES_DIR = "/mnt/data/.dbt"
      DUCKDB_PATH      = "/mnt/data/job_ads.duckdb"
    }
  }

  image_registry_credential {
    server   = azurerm_container_registry.acr.login_server
    username = azurerm_container_registry.acr.admin_username
    password = azurerm_container_registry.acr.admin_password
  }
}
