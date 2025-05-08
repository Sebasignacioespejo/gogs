provider "azurerm" {
  features {}
}

terraform {
  backend "azurerm" {
    resource_group_name  = "gogs-admin"
    storage_account_name = "terraformwow"
    container_name       = "terraform-backend-wow"
    key                  = "infra/network/terraform.tfstate"
  }
}

module "network" {
  source = "../../../modules/azure/network"

  control_ip = var.control_ip
  agent_ip   = var.agent_ip
}
