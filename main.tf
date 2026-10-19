resource "azapi_resource" "this" {
  location  = "global"
  name      = var.name
  parent_id = var.parent_id
  type      = var.resource_types.communication_communication_services
  body = {
    properties = {
      dataLocation        = var.data_location
      disableLocalAuth    = var.disable_local_auth
      linkedDomains       = var.linked_domain_resource_ids
      publicNetworkAccess = var.public_network_access
    }
  }
  ignore_body_changes = length(var.ignore_body_changes.communication_communication_services) > 0 ? var.ignore_body_changes.communication_communication_services : null
  # Leave `publicNetworkAccess` to the service default when it is not supplied.
  ignore_null_property = true
  # `dataLocation` is immutable, so a change to it must replace the service.
  replace_triggers_refs = ["properties.dataLocation"]
  response_export_values = [
    "identity.principalId",
    "properties.hostName",
    "properties.immutableResourceId",
  ]
  retry = var.retry
  tags  = var.tags

  dynamic "identity" {
    for_each = module.avm_interfaces.managed_identities_azapi != null ? [module.avm_interfaces.managed_identities_azapi] : []

    content {
      type         = identity.value.type
      identity_ids = identity.value.identity_ids
    }
  }
  dynamic "timeouts" {
    for_each = var.timeouts == null ? [] : [var.timeouts]

    content {
      create = timeouts.value.create
      delete = timeouts.value.delete
      read   = timeouts.value.read
      update = timeouts.value.update
    }
  }
}
