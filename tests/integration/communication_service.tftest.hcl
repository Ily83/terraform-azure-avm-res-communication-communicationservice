# CI OIDC identity needs subscription-scoped RG creation/deletion and permission to manage Communication Services,
# Email Communication Services, and user-assigned identities.
# It also needs Microsoft.Authorization/roleDefinitions/read and roleAssignments/read,write,delete on the test resource group.
# Terraform test destroys the root module before its setup state, including on assertion failure.

provider "azapi" {
  use_oidc = true
  use_cli  = false
}

variables {
  enable_telemetry = false
}

run "setup" {
  command = apply

  module {
    source = "./tests/integration/fixtures/setup"
  }
}

run "create_communication_service" {
  command = apply

  variables {
    name                       = run.setup.communication_service_name
    parent_id                  = run.setup.parent_id
    data_location              = run.setup.data_location
    disable_local_auth         = true
    linked_domain_resource_ids = [run.setup.linked_domain_resource_id]
    managed_identities = {
      system_assigned            = true
      user_assigned_resource_ids = [run.setup.user_assigned_identity_id]
    }
    role_assignments = {
      reader = {
        principal_id               = run.setup.user_assigned_identity_principal_id
        principal_type             = "ServicePrincipal"
        role_definition_id_or_name = "Reader"
      }
    }
  }

  assert {
    condition     = endswith(output.host_name, ".communication.azure.com")
    error_message = "Azure must return the Communication Service host name."
  }

  assert {
    condition     = output.immutable_resource_id != null && output.system_assigned_mi_principal_id != null
    error_message = "Azure must return the immutable resource ID and the system-assigned principal ID."
  }
}

run "read_communication_service" {
  command = apply

  module {
    source = "./tests/integration/fixtures/readback"
  }

  variables {
    resource_id = run.create_communication_service.resource_id
  }

  assert {
    condition     = [for id in output.communication_service.linked_domains : lower(id)] == [lower(run.setup.linked_domain_resource_id)]
    error_message = "Azure must return the linked Azure managed domain."
  }

  assert {
    condition     = output.communication_service.disable_local_auth == true && output.communication_service.data_location == run.setup.data_location
    error_message = "Azure must persist the local authentication and data location settings."
  }

  assert {
    condition     = replace(output.communication_service.identity_type, " ", "") == "SystemAssigned,UserAssigned"
    error_message = "Azure must return both system- and user-assigned identities."
  }

  assert {
    condition = length([
      for assignment in output.role_assignments : assignment
      if lower(assignment.principal_id) == lower(run.setup.user_assigned_identity_principal_id)
    ]) == 1
    error_message = "Azure must return the Reader role assignment at the Communication Service scope."
  }
}

run "unlink_domains_in_place" {
  command = apply

  variables {
    name               = run.setup.communication_service_name
    parent_id          = run.setup.parent_id
    data_location      = run.setup.data_location
    disable_local_auth = true
  }

  assert {
    condition     = output.resource_id == run.create_communication_service.resource_id && output.immutable_resource_id == run.create_communication_service.immutable_resource_id
    error_message = "Unlinking domains must update the service in place rather than replace it."
  }
}
