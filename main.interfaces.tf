module "avm_interfaces" {
  source  = "Azure/avm-utl-interfaces/azure"
  version = "0.9.0"

  location                         = "global"
  diagnostic_settings_v2           = var.diagnostic_settings
  enable_telemetry                 = var.enable_telemetry
  lock                             = var.lock
  managed_identities               = var.managed_identities
  role_assignment_definition_scope = azapi_resource.this.id
  role_assignments                 = var.role_assignments
}

resource "azapi_resource" "diagnostic_setting" {
  for_each = module.avm_interfaces.diagnostic_settings_azapi_v2

  name                   = coalesce(each.value.name, "diag-${var.name}-${each.key}")
  parent_id              = azapi_resource.this.id
  type                   = var.resource_types.insights_diagnostic_settings
  body                   = each.value.body
  ignore_body_changes    = length(var.ignore_body_changes.insights_diagnostic_settings) > 0 ? var.ignore_body_changes.insights_diagnostic_settings : null
  ignore_null_property   = true
  response_export_values = []
  retry                  = var.retry

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

resource "azapi_resource" "lock" {
  for_each = module.avm_interfaces.lock_azapi == null ? {} : { lock = module.avm_interfaces.lock_azapi }

  name                   = coalesce(each.value.name, "lock-${var.lock.kind}")
  parent_id              = azapi_resource.this.id
  type                   = var.resource_types.authorization_locks
  body                   = each.value.body
  ignore_body_changes    = length(var.ignore_body_changes.authorization_locks) > 0 ? var.ignore_body_changes.authorization_locks : null
  response_export_values = []
  retry                  = var.retry

  dynamic "timeouts" {
    for_each = var.timeouts == null ? [] : [var.timeouts]

    content {
      create = timeouts.value.create
      delete = timeouts.value.delete
      read   = timeouts.value.read
      update = timeouts.value.update
    }
  }

  # A `ReadOnly` lock would block creating or changing the other extension resources.
  depends_on = [
    azapi_resource.diagnostic_setting,
    azapi_resource.role_assignment,
  ]
}

resource "azapi_resource" "role_assignment" {
  for_each = module.avm_interfaces.role_assignments_azapi

  name                 = each.value.name
  parent_id            = azapi_resource.this.id
  type                 = var.resource_types.authorization_role_assignments
  body                 = each.value.body
  ignore_body_changes  = length(var.ignore_body_changes.authorization_role_assignments) > 0 ? var.ignore_body_changes.authorization_role_assignments : null
  ignore_null_property = true
  # Keep both generated and caller-supplied GUIDs, but delete immutable assignments before recreating them.
  replace_triggers_refs = [
    "properties.principalId",
    "properties.roleDefinitionId",
    "properties.delegatedManagedIdentityResourceId",
  ]
  response_export_values = []
  # Role assignments frequently fail immediately after the scope is created because
  # the principal or the scope has not replicated yet.
  retry = var.retry != null ? var.retry : {
    error_message_regex  = tolist(["ScopeLocked", "PrincipalNotFound", "ResourceNotFound"])
    interval_seconds     = 15
    max_interval_seconds = 60
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

  lifecycle {
    # `principalType` is resolved server-side when it is not supplied, which would
    # otherwise show as permanent drift.
    ignore_changes = [body.properties.principalType]
  }
}
