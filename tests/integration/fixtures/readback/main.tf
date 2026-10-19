data "azapi_resource" "communication_service" {
  resource_id = var.resource_id
  type        = "Microsoft.Communication/communicationServices@2026-03-18"
  response_export_values = {
    data_location      = "properties.dataLocation"
    disable_local_auth = "properties.disableLocalAuth"
    host_name          = "properties.hostName"
    identity_type      = "identity.type"
    linked_domains     = "properties.linkedDomains"
  }
}

data "azapi_resource_list" "role_assignments" {
  parent_id = var.resource_id
  type      = "Microsoft.Authorization/roleAssignments@2022-04-01"
  response_export_values = {
    assignments = "value[].{scope: properties.scope, principal_id: properties.principalId, role_definition_id: properties.roleDefinitionId}"
  }
}
