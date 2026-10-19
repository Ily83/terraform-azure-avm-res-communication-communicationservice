variable "data_location" {
  type        = string
  description = "(Required) The geography where the Communication Service stores its data at rest, for example `Europe`, `Switzerland`, or `United States`. Possible values include `Africa`, `Asia Pacific`, `Australia`, `Brazil`, `Canada`, `Europe`, `France`, `Germany`, `India`, `Japan`, `Korea`, `Norway`, `Switzerland`, `UAE`, `UK`, `usgov`, and `United States`. Linked email domains must use the same data location. Changing this forces a new resource to be created."
  nullable    = false

  validation {
    condition     = length(trimspace(var.data_location)) > 0
    error_message = "`data_location` must not be empty."
  }
}

variable "name" {
  type        = string
  description = "(Required) The name of the Communication Service. The name must be globally unique because it forms the `<name>.<geo>.communication.azure.com` host name. Changing this forces a new resource to be created."
  nullable    = false

  validation {
    condition     = can(regex("^[-\\w]{1,63}$", var.name))
    error_message = "`name` must be 1-63 characters long and contain only alphanumerics, underscores, and hyphens."
  }
}

variable "parent_id" {
  type        = string
  description = "(Required) The fully-qualified ARM resource ID of the existing resource group into which the Communication Service will be deployed. Changing this forces a new resource to be created."
  nullable    = false

  validation {
    condition     = can(provider::azapi::parse_resource_id("Microsoft.Resources/resourceGroups", var.parent_id))
    error_message = "`parent_id` must be a valid resource group resource ID."
  }
}

variable "diagnostic_settings" {
  type = map(object({
    name = optional(string, null)
    logs = optional(set(object({
      category       = optional(string, null)
      category_group = optional(string, null)
      enabled        = optional(bool, true)
      retention_policy = optional(object({
        days    = optional(number, 0)
        enabled = optional(bool, false)
      }), {})
    })), [])
    metrics = optional(set(object({
      category = optional(string, null)
      enabled  = optional(bool, true)
      retention_policy = optional(object({
        days    = optional(number, 0)
        enabled = optional(bool, false)
      }), {})
    })), [])
    log_analytics_destination_type           = optional(string, "Dedicated")
    workspace_resource_id                    = optional(string, null)
    storage_account_resource_id              = optional(string, null)
    event_hub_authorization_rule_resource_id = optional(string, null)
    event_hub_name                           = optional(string, null)
    marketplace_partner_resource_id          = optional(string, null)
  }))
  default  = {}
  nullable = false

  validation {
    condition     = alltrue([for _, v in var.diagnostic_settings : contains(["Dedicated", "AzureDiagnostics"], v.log_analytics_destination_type)])
    error_message = "Log analytics destination type must be one of: 'Dedicated', 'AzureDiagnostics'."
  }
  validation {
    condition = alltrue([
      for _, v in var.diagnostic_settings : alltrue([
        for l in v.logs : (l.category != null) != (l.category_group != null)
      ])
    ])
    error_message = "Each log entry must set exactly one of `category` or `category_group`."
  }
  validation {
    condition = alltrue(
      [
        for _, v in var.diagnostic_settings :
        v.workspace_resource_id != null || v.storage_account_resource_id != null || v.event_hub_authorization_rule_resource_id != null || v.marketplace_partner_resource_id != null
      ]
    )
    error_message = "At least one of `workspace_resource_id`, `storage_account_resource_id`, `marketplace_partner_resource_id`, or `event_hub_authorization_rule_resource_id`, must be set."
  }
  validation {
    condition = alltrue([
      for _, v in var.diagnostic_settings :
      v.workspace_resource_id == null || can(provider::azapi::parse_resource_id("Microsoft.OperationalInsights/workspaces", v.workspace_resource_id))
    ])
    error_message = "Each `workspace_resource_id` must be a valid Log Analytics workspace resource ID, or null."
  }
  validation {
    condition = alltrue([
      for _, v in var.diagnostic_settings :
      v.storage_account_resource_id == null || can(provider::azapi::parse_resource_id("Microsoft.Storage/storageAccounts", v.storage_account_resource_id))
    ])
    error_message = "Each `storage_account_resource_id` must be a valid storage account resource ID, or null."
  }
  validation {
    condition = alltrue([
      for _, v in var.diagnostic_settings :
      v.event_hub_authorization_rule_resource_id == null || can(provider::azapi::parse_resource_id("Microsoft.EventHub/namespaces/authorizationRules", v.event_hub_authorization_rule_resource_id))
    ])
    error_message = "Each `event_hub_authorization_rule_resource_id` must be a valid Event Hub namespace authorization rule resource ID, or null."
  }
  description = <<DESCRIPTION
A map of diagnostic settings to create on the resource. The map key is deliberately arbitrary to avoid issues where map keys maybe unknown at plan time.

- `name` - (Optional) The name of the diagnostic setting. One will be generated if not set, however this will not be unique if you want to create multiple diagnostic setting resources.
- `logs` - (Optional) A set of log entries to send to the destination. Each entry has the following attributes:
  - `category` - (Optional) The name of a specific log category to enable. Mutually exclusive with `category_group`.
  - `category_group` - (Optional) The name of a log category group to enable (for example, `allLogs` or `audit`). Mutually exclusive with `category`.
  - `enabled` - (Optional) Whether the log entry is enabled. Defaults to `true`.
  - `retention_policy` - (Optional) The retention policy for the log entry.
    - `days` - (Optional) The retention period in days. Defaults to `0` (retain indefinitely).
    - `enabled` - (Optional) Whether the retention policy is enabled. Defaults to `false`.
- `metrics` - (Optional) A set of metric entries to send to the destination. Each entry has the following attributes:
  - `category` - (Optional) The name of the metric category to enable.
  - `enabled` - (Optional) Whether the metric entry is enabled. Defaults to `true`.
  - `retention_policy` - (Optional) The retention policy for the metric entry, with the same `days` and `enabled` attributes as `logs.retention_policy`.
- `log_analytics_destination_type` - (Optional) The destination type for the diagnostic setting. Possible values are `Dedicated` and `AzureDiagnostics`. Defaults to `Dedicated`.
- `workspace_resource_id` - (Optional) The resource ID of the log analytics workspace to send logs and metrics to.
- `storage_account_resource_id` - (Optional) The resource ID of the storage account to send logs and metrics to.
- `event_hub_authorization_rule_resource_id` - (Optional) The resource ID of the event hub authorization rule to send logs and metrics to.
- `event_hub_name` - (Optional) The name of the event hub. If none is specified, the default event hub will be selected.
- `marketplace_partner_resource_id` - (Optional) The full ARM resource ID of the Marketplace resource to which you would like to send Diagnostic Logs.
DESCRIPTION
}

variable "disable_local_auth" {
  type        = bool
  default     = true
  description = "(Optional) Disables access key (local) authentication so that only Microsoft Entra ID authentication is accepted. Defaults to `true`. Set to `false` when applications still use connection strings or access keys, for example SMTP or SDK clients configured with a connection string."
  nullable    = false
}

variable "enable_telemetry" {
  type        = bool
  default     = true
  description = <<DESCRIPTION
This variable controls whether or not telemetry is enabled for the module.
For more information see <https://aka.ms/avm/telemetryinfo>.
If it is set to false, then no telemetry will be collected.
DESCRIPTION
  nullable    = false
}

variable "ignore_body_changes" {
  type = object({
    communication_communication_services = optional(list(string), [])
    authorization_locks                  = optional(list(string), [])
    authorization_role_assignments       = optional(list(string), [])
    insights_diagnostic_settings         = optional(list(string), [])
  })
  default     = {}
  description = <<DESCRIPTION
Body-relative paths to ignore for each AzAPI resource, keyed by resource. Paths use dot notation. Use this when another process mutates part of a resource and you want Terraform to leave those properties alone.
Changes take effect only after apply. Ignored configuration is not sent to Azure until the path is removed.

- `communication_communication_services` - Paths to ignore on the Communication Service.
- `authorization_locks` - Paths to ignore on the management lock.
- `authorization_role_assignments` - Paths to ignore on the role assignments.
- `insights_diagnostic_settings` - Paths to ignore on the diagnostic settings.

Example: `{ communication_communication_services = ["properties.linkedDomains"] }`
DESCRIPTION
  nullable    = false

  validation {
    condition = alltrue(flatten([
      for _, paths in var.ignore_body_changes : [for path in paths : length(trimspace(path)) > 0]
    ]))
    error_message = "Every `ignore_body_changes` path must be a non-empty string."
  }
}

variable "linked_domain_resource_ids" {
  type        = list(string)
  default     = []
  description = <<DESCRIPTION
(Optional) A list of Email Communication Service domain resource IDs to link to the Communication Service so that it can send email from those domains. Pass the `domain_resource_ids` output of the `avm-res-communication-emailservice` module, for example `values(module.email.domain_resource_ids)`.

A domain can be linked only when it is verified, or is an Azure managed domain, and the Email Communication Service has the same `data_location`. Defaults to `[]` (no linked domains).
DESCRIPTION
  nullable    = false

  validation {
    condition = alltrue([
      for id in var.linked_domain_resource_ids :
      can(provider::azapi::parse_resource_id("Microsoft.Communication/emailServices/domains", id))
    ])
    error_message = "Each entry in `linked_domain_resource_ids` must be a valid `Microsoft.Communication/emailServices/domains` resource ID."
  }
  validation {
    condition     = length(distinct([for id in var.linked_domain_resource_ids : lower(id)])) == length(var.linked_domain_resource_ids)
    error_message = "`linked_domain_resource_ids` must not contain duplicate entries."
  }
}

variable "lock" {
  type = object({
    kind  = string
    name  = optional(string, null)
    notes = optional(string, null)
  })
  default     = null
  description = <<DESCRIPTION
Controls the Resource Lock configuration for this resource. The following properties can be specified:

- `kind` - (Required) The type of lock. Possible values are `\"CanNotDelete\"` and `\"ReadOnly\"`.
- `name` - (Optional) The name of the lock. If not specified, a name will be generated based on the `kind` value. Changing this forces the creation of a new resource.
- `notes` - (Optional) Notes about the lock. This value maps to `Microsoft.Authorization/locks.properties.notes`.
DESCRIPTION

  validation {
    condition     = var.lock != null ? contains(["CanNotDelete", "ReadOnly"], var.lock.kind) : true
    error_message = "Lock kind must be either `\"CanNotDelete\"` or `\"ReadOnly\"`."
  }
}

variable "managed_identities" {
  type = object({
    system_assigned            = optional(bool, false)
    user_assigned_resource_ids = optional(set(string), [])
  })
  default     = {}
  nullable    = false
  description = <<DESCRIPTION
Controls the Managed Identity configuration on this resource. The following properties can be specified:

- `system_assigned` - (Optional) Specifies if the System Assigned Managed Identity should be enabled.
- `user_assigned_resource_ids` - (Optional) Specifies a list of User Assigned Managed Identity resource IDs to be assigned to this resource.
DESCRIPTION

  validation {
    condition = alltrue([
      for id in var.managed_identities.user_assigned_resource_ids :
      can(provider::azapi::parse_resource_id("Microsoft.ManagedIdentity/userAssignedIdentities", id))
    ])
    error_message = "Each entry in `managed_identities.user_assigned_resource_ids` must be a valid user-assigned managed identity resource ID."
  }
}

variable "public_network_access" {
  type        = string
  default     = null
  description = "(Optional) Whether the Communication Service accepts traffic from public networks. Possible values are `Enabled`, `Disabled`, and `SecuredByPerimeter`. Defaults to `null`, which leaves the service default (`Enabled`) in place."

  validation {
    condition     = contains(["Enabled", "Disabled", "SecuredByPerimeter"], coalesce(var.public_network_access, "Enabled"))
    error_message = "`public_network_access` must be one of `Enabled`, `Disabled`, or `SecuredByPerimeter`, or null."
  }
}

variable "resource_types" {
  type = object({
    communication_communication_services = optional(string, "Microsoft.Communication/communicationServices@2026-03-18")
    authorization_locks                  = optional(string, "Microsoft.Authorization/locks@2020-05-01")
    authorization_role_assignments       = optional(string, "Microsoft.Authorization/roleAssignments@2022-04-01")
    insights_diagnostic_settings         = optional(string, "Microsoft.Insights/diagnosticSettings@2021-05-01-preview")
  })
  default     = {}
  description = <<DESCRIPTION
The ARM resource type and API version used for each resource this module deploys. Override an entry to pin a different API version.

- `communication_communication_services` - The Communication Service.
- `authorization_locks` - The management lock.
- `authorization_role_assignments` - The role assignments.
- `insights_diagnostic_settings` - The diagnostic settings.
DESCRIPTION
  nullable    = false
}

variable "retry" {
  type = object({
    error_message_regex  = optional(list(string))
    interval_seconds     = optional(number)
    max_interval_seconds = optional(number)
  })
  default     = null
  description = <<DESCRIPTION
Retry configuration applied to every `azapi` resource managed by the module (root resource and all submodules). Defaults to `null` (no custom retry).

- `error_message_regex`  - (Optional) A list of regex patterns matching error messages that trigger a retry.
- `interval_seconds`     - (Optional) Initial interval between retries in seconds.
- `max_interval_seconds` - (Optional) Maximum interval between retries in seconds.

See <https://registry.terraform.io/providers/Azure/azapi/latest/docs/resources/resource#retry> for full semantics.
DESCRIPTION
}

variable "role_assignments" {
  type = map(object({
    name                                   = optional(string, null)
    role_definition_id_or_name             = string
    principal_id                           = string
    description                            = optional(string, null)
    skip_service_principal_aad_check       = optional(bool, false)
    condition                              = optional(string, null)
    condition_version                      = optional(string, null)
    delegated_managed_identity_resource_id = optional(string, null)
    principal_type                         = optional(string, null)
  }))
  default     = {}
  nullable    = false
  description = <<DESCRIPTION
A map of role assignments to create on the Communication Service. The map key is deliberately arbitrary to avoid issues where map keys maybe unknown at plan time.

- `name` - (Optional) The name of the role assignment. If not set, a random UUID will be generated. Changing this forces the creation of a new resource.
- `role_definition_id_or_name` - The ID or name of the role definition to assign to the principal.
- `principal_id` - The ID of the principal to assign the role to.
- `description` - (Optional) The description of the role assignment.
- `skip_service_principal_aad_check` - (Optional) If set to true, skips the Azure Active Directory check for the service principal in the tenant. Defaults to false.
- `condition` - (Optional) The condition which will be used to scope the role assignment.
- `condition_version` - (Optional) The version of the condition syntax. Leave as `null` if you are not using a condition, if you are then valid values are '2.0'.
- `delegated_managed_identity_resource_id` - (Optional) The delegated Azure Resource Id which contains a Managed Identity. Changing this forces a new resource to be created. This field is only used in cross-tenant scenario.
- `principal_type` - (Optional) The type of the `principal_id`. Possible values are `User`, `Group` and `ServicePrincipal`. It is necessary to explicitly set this attribute when creating role assignments if the principal creating the assignment is constrained by ABAC rules that filters on the PrincipalType attribute.

> Note: only set `skip_service_principal_aad_check` to true if you are assigning a role to a service principal.
DESCRIPTION

  validation {
    condition = alltrue([
      for _, v in var.role_assignments :
      v.delegated_managed_identity_resource_id == null || can(provider::azapi::parse_resource_id("Microsoft.ManagedIdentity/userAssignedIdentities", v.delegated_managed_identity_resource_id))
    ])
    error_message = "Each `role_assignments[*].delegated_managed_identity_resource_id` must be a valid user-assigned managed identity resource ID, or null."
  }
}

variable "tags" {
  type        = map(string)
  default     = null
  description = "(Optional) Tags of the resource."
}

variable "timeouts" {
  type = object({
    create = optional(string)
    read   = optional(string)
    update = optional(string)
    delete = optional(string)
  })
  default     = null
  description = <<DESCRIPTION
Default per-operation timeouts applied to every `azapi` resource managed by the module. Defaults to `null` (provider defaults). Each value is a Go duration string (e.g. `30m`, `1h`).

- `create` - (Optional) Timeout for create operations.
- `read`   - (Optional) Timeout for read operations.
- `update` - (Optional) Timeout for update operations.
- `delete` - (Optional) Timeout for delete operations.
DESCRIPTION
}
