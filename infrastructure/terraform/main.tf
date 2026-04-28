provider "azurerm" {
  features {}
}

provider "aws" {
  region = var.aws_region
}

resource "azurerm_resource_group" "dr_testing" {
  name     = "rg-${var.project_name}-testing-${var.environment}"
  location = var.location
}

# --- Resilience Testing Hub (AKS) ---

resource "azurerm_kubernetes_cluster" "testing_k8s" {
  name                = "aks-drill-engine-${var.environment}"
  location            = azurerm_resource_group.dr_testing.location
  resource_group_name = azurerm_resource_group.dr_testing.name
  dns_prefix          = "drill-k8s"

  default_node_pool {
    name       = "default"
    node_count = 3
    vm_size    = "Standard_D2s_v3"
  }

  identity {
    type = "SystemAssigned"
  }
}

# --- Readiness Metadata Store (Postgres) ---

resource "azurerm_postgresql_flexible_server" "readiness" {
  name                   = "psql-readiness-metadata-${var.environment}"
  resource_group_name    = azurerm_resource_group.dr_testing.name
  location               = azurerm_resource_group.dr_testing.location
  version                = "13"
  administrator_login    = "drilladmin"
  administrator_password = var.db_password
  storage_mb             = 32768
  sku_name               = "GP_Standard_D2ds_v4"
}

# --- Evidence Sink (Multi-Cloud Shared Service - Azure Storage) ---

resource "azurerm_storage_account" "evidence" {
  name                     = "sttestingevidence${var.environment}"
  resource_group_name      = azurerm_resource_group.dr_testing.name
  location                 = azurerm_resource_group.dr_testing.location
  account_tier             = "Standard"
  account_replication_type = "GRS"

  blob_properties {
    versioning_enabled = true
  }
}

# --- Multi-Cloud Persistence (AWS S3 Evidence Copy) ---

resource "aws_s3_bucket" "evidence_copy" {
  bucket = "db-drill-evidence-copy-${var.environment}"
}
