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
  name     = "myTFResourceGroup"
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
  name                     = lower("${substr(var.prefix_app_name,0,5)}st${random_integer.number.result}") # ≤24 chars
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_share" "file_share" {
  name                 = "data"
  storage_account_name = azurerm_storage_account.storage.name
  quota                = 10 # GB
}

# -------------------------------
# Azure Container Registry (ACR)
# -------------------------------
resource "azurerm_container_registry" "acr" {
  name                = lower("${substr(var.prefix_app_name,0,5)}acr${random_integer.number.result}") # ≤24 chars
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "Basic"
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
  sku_name            = "B1"
}

# -------------------------------
# Web App (Streamlit Dashboard)
# -------------------------------
# resource "azurerm_linux_web_app" "dashboard" {
#   name                = "${var.prefix_app_name}-dashboard-app"
#   resource_group_name = azurerm_resource_group.rg.name
#   location            = azurerm_resource_group.rg.location
#   service_plan_id     = azurerm_service_plan.asp.id

#   site_config {
#     always_on = true
#   }

#   app_settings = {
#     WEBSITES_PORT                   = "8501"
#     DOCKER_REGISTRY_SERVER_URL      = "https://${azurerm_container_registry.acr.login_server}"
#     DOCKER_REGISTRY_SERVER_USERNAME = azurerm_container_registry.acr.admin_username
#     DOCKER_REGISTRY_SERVER_PASSWORD = azurerm_container_registry.acr.admin_password
#     DOCKER_CUSTOM_IMAGE_NAME        = "${azurerm_container_registry.acr.login_server}/${var.prefix_app_name}-dashboard:latest"
#   }
# }
