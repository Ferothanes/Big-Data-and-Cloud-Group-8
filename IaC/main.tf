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
    application_stack {
      docker_image_name   = "${azurerm_container_registry.acr.login_server}/${var.prefix_app_name}-dashboard:latest"
      docker_registry_url = "https://${azurerm_container_registry.acr.login_server}"
    }
    always_on = true
  }

  app_settings = {
    DOCKER_REGISTRY_SERVER_URL      = "https://${azurerm_container_registry.acr.login_server}"
    DOCKER_REGISTRY_SERVER_USERNAME = azurerm_container_registry.acr.admin_username
    DOCKER_REGISTRY_SERVER_PASSWORD = azurerm_container_registry.acr.admin_password
    WEBSITES_PORT                   = "8501"
  }
}
