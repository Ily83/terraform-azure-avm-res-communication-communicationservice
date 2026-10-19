output "communication_service_name" {
  value = "acs-int-${random_string.suffix.result}"
}

output "data_location" {
  value = azapi_resource.email_service.body.properties.dataLocation
}

output "linked_domain_resource_id" {
  value = azapi_resource.email_domain.id
}

output "parent_id" {
  value = azapi_resource.resource_group.id
}

output "user_assigned_identity_id" {
  value = azapi_resource.identity.id
}

output "user_assigned_identity_principal_id" {
  value = azapi_resource.identity.output.properties.principalId
}
