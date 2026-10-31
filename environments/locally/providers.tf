terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.0"
    }
  }
}

provider "azurerm" {
  features {}
}

module "app-service-deployment-slots" {
  source = "../../modules/app-service-deployment-slots"

  name_prefix = "locally-example-slots"
  location    = "berlin"
  tags = {
    ProvisionedVia = "Terraform"
  }
}
