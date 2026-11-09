terraform {
  required_version = "~> 1.11"

  required_providers {
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.13"
    }
    # tflint-ignore: terraform_unused_required_providers
    random = {
      source  = "hashicorp/random"
      version = "~> 3.9"
    }
  }
}
