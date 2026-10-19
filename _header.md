# terraform-azure-avm-res-communication-communicationservice

This is an AVM module to deploy an Azure Communication Service (`Microsoft.Communication/communicationServices`) with the AzAPI provider.

The module can link the domains of an Email Communication Service, deployed with the [`avm-res-communication-emailservice`](https://registry.terraform.io/modules/Azure/avm-res-communication-emailservice/azurerm/latest) module, to the Communication Service so that it can send email from those domains. It also supports managed identities, role assignments, diagnostic settings, and a management lock.

> [!IMPORTANT]
> As the overall AVM framework is not GA (generally available) yet - the CI framework and test automation is not fully functional and implemented across all supported languages yet - breaking changes are expected, and additional customer feedback is yet to be gathered and incorporated. Hence, modules **MUST NOT** be published at version `1.0.0` or higher at this time.
>
> All module **MUST** be published as a pre-release version (e.g., `0.1.0`, `0.1.1`, `0.2.0`, etc.) until the AVM framework becomes GA.
>
> However, it is important to note that this **DOES NOT** mean that the modules cannot be consumed and utilized. They **CAN** be leveraged in all types of environments (dev, test, prod etc.). Consumers can treat them just like any other IaC module and raise issues or feature requests against them as they learn from the usage of the module. Consumers should also read the release notes for each version, if considering updating to a more recent version of a module to see if there are any considerations or breaking changes etc.

## Linking email domains

Pass the `domain_resource_ids` output of the Email Communication Service module to `linked_domain_resource_ids`:

```hcl
module "communication_service" {
  source  = "Azure/avm-res-communication-communicationservice/azure"
  version = "0.1.0"

  name                       = "acs-example"
  parent_id                  = azapi_resource.resource_group.id
  data_location              = "Switzerland"
  linked_domain_resource_ids = values(module.email.domain_resource_ids)
}
```

A domain can be linked only when it is an Azure managed domain or a verified customer managed domain, and when its Email Communication Service uses the same `data_location`.

## Local authentication

`disable_local_auth` defaults to `true`, so only Microsoft Entra ID authentication is accepted. Set it to `false` when applications still authenticate with connection strings or access keys. The module never outputs keys or connection strings.

## Importing an existing Communication Service

Communication Services are global resources, and `data_location` cannot be changed without replacing the resource. To bring an existing service under management, configure the module with the service's current `name`, `data_location`, `disable_local_auth`, linked domains, identity, and tags, then import it:

```hcl
import {
  to = module.communication_service.azapi_resource.this
  id = "/subscriptions/<subscription_id>/resourceGroups/<resource_group_name>/providers/Microsoft.Communication/communicationServices/<name>?api-version=2026-03-18"
}
```

Run `terraform plan` and confirm that it does not plan a replacement of `azapi_resource.this` before you apply. Import existing locks and role assignments in the same way, at `azapi_resource.lock["lock"]` and `azapi_resource.role_assignment["<key>"]`, and set the existing lock name and role assignment GUIDs in `lock.name` and `role_assignments[<key>].name`.
