# Default example

This deploys a Communication Service and links the Azure managed domain of an Email Communication Service deployed with the [`avm-res-communication-emailservice`](https://registry.terraform.io/modules/Azure/avm-res-communication-emailservice/azurerm/latest) module, so that the Communication Service can send email from that domain.

Local (access key) authentication is disabled by default, so senders must use Microsoft Entra ID.
