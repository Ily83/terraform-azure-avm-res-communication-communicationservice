output "host_name" {
  description = "The host name of the Communication Service, for example `<name>.<geo>.communication.azure.com`."
  value       = azapi_resource.this.output.properties.hostName
}

output "immutable_resource_id" {
  description = "The immutable resource ID of the Communication Service."
  value       = azapi_resource.this.output.properties.immutableResourceId
}

output "name" {
  description = "The name of the Communication Service."
  value       = azapi_resource.this.name
}

output "resource_id" {
  description = "The resource ID of the Communication Service."
  value       = azapi_resource.this.id
}

output "system_assigned_mi_principal_id" {
  description = "The principal ID of the system-assigned managed identity, or `null` when it is not enabled."
  value       = try(azapi_resource.this.output.identity.principalId, null)
}
