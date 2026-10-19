data "azapi_client_config" "current" {}

resource "random_string" "name_suffix" {
  length  = 6
  numeric = true
  special = false
  upper   = false
}

resource "azapi_resource" "resource_group" {
  location               = var.location
  name                   = "rg-avm-res-communication-communicationservice-${random_string.name_suffix.result}"
  parent_id              = "/subscriptions/${data.azapi_client_config.current.subscription_id}"
  type                   = "Microsoft.Resources/resourceGroups@2025-04-01"
  response_export_values = []
}

# The Email Communication Service supplies the Azure managed domain that is linked below.
# Its `data_location` must match the Communication Service.
module "email" {
  source  = "Azure/avm-res-communication-emailservice/azurerm"
  version = "0.3.0"

  data_location = "Switzerland"
  location      = azapi_resource.resource_group.location
  name          = "ecs-${random_string.name_suffix.result}"
  parent_id     = azapi_resource.resource_group.id
  email_communication_service_domains = {
    azure_managed = {
      name              = "AzureManagedDomain"
      domain_management = "AzureManaged"
    }
  }
  enable_telemetry = var.enable_telemetry
}

# This is the module call
module "test" {
  source = "../../"

  data_location              = "Switzerland"
  name                       = "acs-${random_string.name_suffix.result}"
  parent_id                  = azapi_resource.resource_group.id
  enable_telemetry           = var.enable_telemetry # see variables.tf
  linked_domain_resource_ids = values(module.email.domain_resource_ids)
  managed_identities = {
    system_assigned = true
  }
  tags = {
    env = "Test"
  }
}
