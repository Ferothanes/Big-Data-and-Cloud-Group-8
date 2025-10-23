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
  name     = "myTFResourceGroup"       # <<< CHANGE if you want a different RG name
  location = "swedencentral"          
}

# -------------------------------
# Azure resource names must be unique — this adds a random number (e.g., acr12345) 
# so Terraform doesn’t fail if the name already exists.
# -------------------------------
resource "random_integer" "number" {
  min = 10000
  max = 99999
}

# -------------------------------
# Azure Container Registry (ACR)
# -------------------------------
resource "azurerm_container_registry" "acr" {
  name                = "acr${random_integer.number.result}"    # Generates a unique ACR name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "Basic"  <<< CHEAP 
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
  sku_name            = "B1"            # <<< B1 for cheaper dev/test tier
}

# -------------------------------
# Web App (Containerized)
# -------------------------------
resource "azurerm_linux_web_app" "app" {
  name                = "${var.prefix_app_name}-app"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  service_plan_id     = azurerm_service_plan.asp.id

  site_config {
    application_stack {
      docker_image_name   = "${azurerm_container_registry.acr.login_server}/${var.prefix_app_name}:latest"
      docker_registry_url = "https://${azurerm_container_registry.acr.login_server}"
    }

    always_on = true  # <<< Adjust? Keeps app alive (recommended for pipelines/dashboards)
  }

  # Environment variables + ACR credentials
  app_settings = {
    DOCKER_REGISTRY_SERVER_URL      = "https://${azurerm_container_registry.acr.login_server}"
    DOCKER_REGISTRY_SERVER_USERNAME = azurerm_container_registry.acr.admin_username
    DOCKER_REGISTRY_SERVER_PASSWORD = azurerm_container_registry.acr.admin_password


    WEBSITES_PORT                   = "8080"  #<<< PORT 
  }
}
