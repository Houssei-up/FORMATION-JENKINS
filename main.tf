terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=2.46.0"
    }
  }
}

#Un provider joue le meme role que les librairies 
#Configure the Microsoft Azure Provider azure

provider "azurerm" {
  features {}
}
#création ressource azure
resource "azurerm_resource_group" "rg01" {
  name     = "rg-housseinatou" 
  location = var.location
}

#Create storage account

resource "azurerm_storage_account" "st01" {
  name                     = "storagehousseinatou"
  resource_group_name      = azurerm_resource_group.rg01.name 
  location                 = azurerm_resource_group.rg01.location  // "West Europe"
  account_tier             = "Standard"
  account_replication_type = "LRS"

#Change acces TIER en cool

  access_tier    = "Cool"
  
}


#Create Contenair 

resource "azurerm_storage_container" "cont01" {
  name                     = "containerhousseina"
  storage_account_name     = azurerm_storage_account.st01.name
  container_access_type    = "private"

}

#Datasource
data "azurerm_client_config" "current" {} 


resource "azurerm_key_vault" "KEY01" {
  name                        = "keyvaultHousseinatou"
  location                    = azurerm_resource_group.rg01.location
  resource_group_name         = azurerm_resource_group.rg01.name
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id    
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false

  sku_name = "standard"

  //les droits secret 

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id 
    object_id = data.azurerm_client_config.current.object_id 



    key_permissions = [ "Get" ]

    secret_permissions = [
      "Get", "Set" , "List", "Backup", "Delete", "Purge", "Recover", "Restore" 

    ]
  }
}

#Creer un 2eme conteneur sur le storage account de rg-raphael à l'aide d'un data source
data "azurerm_storage_account" "dataraphael" {

    name                = "storageraphael"
    resource_group_name = "rg-raphael"
} 

resource "azurerm_storage_container" "cont02" {
  name                     = "containerhousseinatou"
  storage_account_name     = data.azurerm_storage_account.dataraphael.name 
  container_access_type    = "private"

}

#Générer un mot de passe aléatoire 
resource "random_password" "pwd01" {
  length           = 16
  special          = true
  override_special = "_%@"
  min_upper        = 1
  min_special      = 1
  min_lower        = 1
  min_numeric      = 1
}


#Create mysqlserver
resource "azurerm_mssql_server" "sql01" {
  name                         = "sqlhousseinatou"
  resource_group_name          = azurerm_resource_group.rg01.name
  location                     = azurerm_resource_group.rg01.location
  version                      = "12.0"
  administrator_login          = "Houssei"
  administrator_login_password = random_password.pwd01.result   //récupére le mot de passe généré random_password.pwd01.result 
  minimum_tls_version          = "1.2"

 tags = {
    environment = "production"
  }

/*   Pas vraiment nécessaire 
  azuread_administrator {
    login_username = "AzureAD Admin"
    object_id      = "00000000-0000-0000-0000-000000000000" //ou data.azurerm_client_config.current.object_id
  }*/
}

#Créer un secret dans le KEYVAULT crée précédement  


resource "azurerm_key_vault_secret" "secret_pwd" {
  name         = "secretpassword"
  value        = random_password.pwd01.result
  key_vault_id = azurerm_key_vault.KEY01.id
}

#Deployer une DATABASE sur votre SQL SERVER
//General Purpose Serverless avec Autopause de 2h 
/*
resource "azurerm_mssql_database" "database_sql" {
  name           = "DB_HOUSSEINATOU"
  server_id      = azurerm_mssql_server.sql01.id
  collation      = "SQL_Latin1_General_CP1_CI_AS"
 // license_type   = "BasePrice"
  auto_pause_delay_in_minutes =  120 // si -1 comme valeur la base de sonnées ne s'éteidra jamais 
  max_size_gb    = 4
  read_scale     = false //car n'accepte pas le read_scale
  sku_name       = "GP_S_Gen5_1"
  //zone_redundant = true
  min_capacity = 1

}
*/
#Déployer un log analytics Workspace

resource "azurerm_log_analytics_workspace" "log01" {
  name                = "logHousseinatou"
  location            = azurerm_resource_group.rg01.location
  resource_group_name = azurerm_resource_group.rg01.name
  sku                 = "PerGB2018"
  retention_in_days   = var.retention_keyVault 
}
#Envoyer tous les logs et les metrics du keyVault dans le log Analytics workspace crée précédement
//Monotor Diagnostics Setting

resource "azurerm_monitor_diagnostic_setting" "MDS01" {
  name               = "MonitorHousseinatou"
  target_resource_id = azurerm_key_vault.KEY01.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.log01.id //possible de le stocker également dans un storage account 

    log {
    category = "AuditEvent"
    enabled  = true

    retention_policy {
      enabled = true
    }
  }
  log {
    category = "AzurePolicyEvaluationDetails"
    enabled  = true

    retention_policy { 
      enabled = true
    }
  }


  metric {
    category = "AllMetrics"

   retention_policy {
      enabled = true
    }

  }
}

#Déployer 3 Resources Group avec COUNT

resource "azurerm_resource_group" "Countrg" {
  count = 3 
  name     = "rgHoussei-${count.index}" 
  location = var.location

}
#Variables 
//pour l'utiliser on fait var.location
variable "location" {
  type = string
  default = "West Europe"
}
