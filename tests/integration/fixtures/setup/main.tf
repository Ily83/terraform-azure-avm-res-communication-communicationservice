data "azapi_client_config" "current" {}

resource "random_string" "suffix" {
  length  = 10
  special = false
  upper   = false
}

resource "azapi_resource" "resource_group" {
  location               = "switzerlandnorth"
  name                   = "rg-acs-int-${random_string.suffix.result}"
  parent_id              = "/subscriptions/${data.azapi_client_config.current.subscription_id}"
  type                   = "Microsoft.Resources/resourceGroups@2025-04-01"
  response_export_values = []
}

resource "azapi_resource" "email_service" {
  location  = "global"
  name      = "ecs-acs-int-${random_string.suffix.result}"
  parent_id = azapi_resource.resource_group.id
  type      = "Microsoft.Communication/emailServices@2026-03-18"
  body = {
    properties = {
      dataLocation = "Switzerland"
    }
  }
  response_export_values = []
}

resource "azapi_resource" "email_domain" {
  location  = "global"
  name      = "AzureManagedDomain"
  parent_id = azapi_resource.email_service.id
  type      = "Microsoft.Communication/emailServices/domains@2026-03-18"
  body = {
    properties = {
      domainManagement = "AzureManaged"
    }
  }
  response_export_values = []
}

resource "azapi_resource" "identity" {
  location               = azapi_resource.resource_group.location
  name                   = "id-acs-int-${random_string.suffix.result}"
  parent_id              = azapi_resource.resource_group.id
  type                   = "Microsoft.ManagedIdentity/userAssignedIdentities@2024-11-30"
  body                   = {}
  response_export_values = ["properties.principalId"]
}
