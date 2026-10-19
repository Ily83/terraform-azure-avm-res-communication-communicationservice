mock_provider "azapi" {
  mock_resource "azapi_resource" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Communication/communicationServices/acs-test"
      output = {
        identity = {
          principalId = "00000000-0000-0000-0000-000000000009"
        }
        properties = {
          hostName            = "acs-test.switzerland.communication.azure.com"
          immutableResourceId = "00000000-0000-0000-0000-000000000008"
        }
      }
    }
  }
}

mock_provider "modtm" {}
mock_provider "random" {
  mock_resource "random_uuid" {
    defaults = {
      result = "11111111-1111-4111-8111-111111111111"
    }
  }
}

# The interfaces module looks up role definitions by name whenever role assignments are supplied.
override_data {
  target = module.avm_interfaces.data.azapi_resource_list.role_definitions[0]
  values = {
    output = { results = [] }
  }
}

variables {
  name             = "acs-test"
  parent_id        = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test"
  data_location    = "Switzerland"
  enable_telemetry = false

  tags = {
    env = "Prod"
  }
}

run "defaults" {
  command = plan

  assert {
    condition     = azapi_resource.this.type == "Microsoft.Communication/communicationServices@2026-03-18"
    error_message = "The Communication Service must default to the latest GA API version."
  }

  assert {
    condition     = azapi_resource.this.location == "global"
    error_message = "Communication Services are global resources."
  }

  assert {
    condition     = azapi_resource.this.body.properties.dataLocation == "Switzerland"
    error_message = "`data_location` must map to `properties.dataLocation`."
  }

  assert {
    condition     = azapi_resource.this.body.properties.disableLocalAuth == true
    error_message = "Local (access key) authentication must be disabled by default."
  }

  assert {
    condition     = length(azapi_resource.this.body.properties.linkedDomains) == 0
    error_message = "No email domains should be linked by default."
  }

  assert {
    condition     = azapi_resource.this.body.properties.publicNetworkAccess == null && azapi_resource.this.ignore_null_property
    error_message = "`publicNetworkAccess` must not be sent unless it is supplied."
  }

  assert {
    condition     = azapi_resource.this.tags == tomap({ env = "Prod" })
    error_message = "`tags` must be applied to the Communication Service."
  }

  assert {
    condition     = length(azapi_resource.this.identity) == 0
    error_message = "No managed identity block should be rendered by default."
  }

  assert {
    condition     = length(azapi_resource.lock) == 0 && length(azapi_resource.role_assignment) == 0 && length(azapi_resource.diagnostic_setting) == 0
    error_message = "No extension resources should be created by default."
  }

  assert {
    condition     = azapi_resource.this.replace_triggers_refs == tolist(["properties.dataLocation"])
    error_message = "Only `properties.dataLocation` should force replacement of the service."
  }

  assert {
    condition     = azapi_resource.this.ignore_body_changes == null
    error_message = "An empty `ignore_body_changes` list must collapse to null."
  }
}

run "outputs" {
  command = apply

  assert {
    condition     = output.resource_id == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Communication/communicationServices/acs-test"
    error_message = "`resource_id` must expose the Communication Service ID."
  }

  assert {
    condition     = output.name == "acs-test"
    error_message = "`name` must expose the Communication Service name."
  }

  assert {
    condition     = output.host_name == "acs-test.switzerland.communication.azure.com"
    error_message = "`host_name` must expose `properties.hostName`."
  }

  assert {
    condition     = output.immutable_resource_id == "00000000-0000-0000-0000-000000000008"
    error_message = "`immutable_resource_id` must expose `properties.immutableResourceId`."
  }

  assert {
    condition     = output.system_assigned_mi_principal_id == "00000000-0000-0000-0000-000000000009"
    error_message = "`system_assigned_mi_principal_id` must expose `identity.principalId`."
  }
}

run "linked_domains_and_settings" {
  command = plan

  variables {
    linked_domain_resource_ids = [
      "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Communication/emailServices/ecs-test/domains/AzureManagedDomain",
      "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Communication/emailServices/ecs-test/domains/example.com",
    ]
    disable_local_auth    = false
    public_network_access = "Disabled"
  }

  assert {
    condition = azapi_resource.this.body.properties.linkedDomains == tolist([
      "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Communication/emailServices/ecs-test/domains/AzureManagedDomain",
      "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Communication/emailServices/ecs-test/domains/example.com",
    ])
    error_message = "`linked_domain_resource_ids` must map to `properties.linkedDomains` in order."
  }

  assert {
    condition     = azapi_resource.this.body.properties.disableLocalAuth == false
    error_message = "`disable_local_auth` must map to `properties.disableLocalAuth`."
  }

  assert {
    condition     = azapi_resource.this.body.properties.publicNetworkAccess == "Disabled"
    error_message = "`public_network_access` must map to `properties.publicNetworkAccess`."
  }
}

run "system_and_user_assigned_identity" {
  command = plan

  variables {
    managed_identities = {
      system_assigned            = true
      user_assigned_resource_ids = ["/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-test"]
    }
  }

  assert {
    condition     = azapi_resource.this.identity[0].type == "SystemAssigned, UserAssigned"
    error_message = "Both system- and user-assigned identities must be configured."
  }

  assert {
    condition     = azapi_resource.this.identity[0].identity_ids == tolist(["/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-test"])
    error_message = "User-assigned identity IDs must be passed to the identity block."
  }
}

run "system_assigned_identity_only" {
  command = plan

  variables {
    managed_identities = {
      system_assigned = true
    }
  }

  assert {
    condition     = azapi_resource.this.identity[0].type == "SystemAssigned"
    error_message = "Only the system-assigned identity must be configured."
  }
}

run "lock_is_created_when_requested" {
  command = plan

  variables {
    lock = {
      kind = "CanNotDelete"
    }
  }

  assert {
    condition     = azapi_resource.lock["lock"].name == "lock-CanNotDelete"
    error_message = "The lock name should default to `lock-<kind>` when no name is supplied."
  }

  assert {
    condition     = azapi_resource.lock["lock"].type == "Microsoft.Authorization/locks@2020-05-01"
    error_message = "The lock should be created with the Microsoft.Authorization/locks resource type."
  }

  assert {
    condition     = azapi_resource.lock["lock"].body.properties.level == "CanNotDelete"
    error_message = "The lock level must match `lock.kind`."
  }
}

run "diagnostic_settings" {
  command = plan

  variables {
    diagnostic_settings = {
      law = {
        workspace_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.OperationalInsights/workspaces/law-test"
        logs                  = [{ category_group = "allLogs" }]
        metrics               = [{ category = "AllMetrics" }]
      }
      named = {
        name                        = "diag-custom"
        storage_account_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Storage/storageAccounts/sttest"
      }
    }
  }

  assert {
    condition     = azapi_resource.diagnostic_setting["law"].name == "diag-acs-test-law" && azapi_resource.diagnostic_setting["named"].name == "diag-custom"
    error_message = "Diagnostic settings must use the supplied name, or a unique generated name."
  }

  assert {
    condition     = azapi_resource.diagnostic_setting["law"].type == "Microsoft.Insights/diagnosticSettings@2021-05-01-preview"
    error_message = "Diagnostic settings must use the Microsoft.Insights/diagnosticSettings resource type."
  }

  assert {
    condition     = azapi_resource.diagnostic_setting["law"].body.properties.workspaceId == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.OperationalInsights/workspaces/law-test"
    error_message = "The workspace ID must be passed to the diagnostic setting."
  }

  assert {
    condition     = azapi_resource.diagnostic_setting["law"].body.properties.logs[0].categoryGroup == "allLogs" && azapi_resource.diagnostic_setting["law"].body.properties.metrics[0].category == "AllMetrics"
    error_message = "Log category groups and metric categories must be passed to the diagnostic setting."
  }
}

run "role_assignments" {
  command = apply

  variables {
    role_assignments = {
      generated = {
        principal_id               = "00000000-0000-0000-0000-000000000003"
        role_definition_id_or_name = "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/roleDefinitions/acdd72a7-3385-48ef-bd42-f606fba81ae7"
      }
      explicit = {
        name                       = "22222222-2222-4222-8222-222222222222"
        principal_id               = "00000000-0000-0000-0000-000000000003"
        role_definition_id_or_name = "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/roleDefinitions/acdd72a7-3385-48ef-bd42-f606fba81ae7"
      }
    }
  }

  assert {
    condition = alltrue([
      for assignment in azapi_resource.role_assignment : assignment.replace_triggers_refs == tolist([
        "properties.principalId",
        "properties.roleDefinitionId",
        "properties.delegatedManagedIdentityResourceId",
      ])
    ])
    error_message = "All immutable role fields must trigger replacement; description and condition must remain mutable."
  }

  assert {
    condition     = azapi_resource.role_assignment["generated"].name == "11111111-1111-4111-8111-111111111111"
    error_message = "An omitted name must retain the GUID generated by the interfaces module."
  }

  assert {
    condition     = azapi_resource.role_assignment["explicit"].name == "22222222-2222-4222-8222-222222222222"
    error_message = "A caller-supplied role assignment GUID must be preserved."
  }
}

run "resource_types_can_be_overridden" {
  command = plan

  variables {
    resource_types = {
      communication_communication_services = "Microsoft.Communication/communicationServices@2025-09-01"
    }
  }

  assert {
    condition     = azapi_resource.this.type == "Microsoft.Communication/communicationServices@2025-09-01"
    error_message = "`resource_types` should control the API version used for the Communication Service."
  }
}

# `ignore_body_changes` is provider-private state, so only its validation is asserted here.
run "ignore_body_changes_rejects_empty_paths" {
  command = plan

  variables {
    ignore_body_changes = {
      communication_communication_services = [" "]
    }
  }

  expect_failures = [var.ignore_body_changes]
}

run "parent_id_rejects_a_non_resource_group_id" {
  command = plan

  variables {
    parent_id = "/subscriptions/00000000-0000-0000-0000-000000000000"
  }

  expect_failures = [var.parent_id]
}

run "name_rejects_invalid_characters" {
  command = plan

  variables {
    name = "acs.test"
  }

  expect_failures = [var.name]
}

run "linked_domain_resource_ids_rejects_non_domain_ids" {
  command = plan

  variables {
    linked_domain_resource_ids = ["/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Communication/emailServices/ecs-test"]
  }

  expect_failures = [var.linked_domain_resource_ids]
}

run "linked_domain_resource_ids_rejects_duplicates" {
  command = plan

  variables {
    linked_domain_resource_ids = [
      "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Communication/emailServices/ecs-test/domains/example.com",
      "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Communication/emailServices/ecs-test/domains/EXAMPLE.com",
    ]
  }

  expect_failures = [var.linked_domain_resource_ids]
}

run "public_network_access_rejects_unknown_values" {
  command = plan

  variables {
    public_network_access = "Open"
  }

  expect_failures = [var.public_network_access]
}
