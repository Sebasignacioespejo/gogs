provider "azurerm" {
  features {}
}

terraform {
  backend "azurerm" {
    resource_group_name  = "gogs-admin"
    storage_account_name = "terraformwow"
    container_name       = "terraform-backend-wow"
    key                  = "infra/vm/terraform.tfstate"
  }
}

module "network" {
  source = "../../../modules/azure/vm"

  rsg_name     = data.terraform_remote_state.network_tfstate.outputs.rsg_name
  rsg_location = data.terraform_remote_state.network_tfstate.outputs.rsg_location
  nic_id       = data.terraform_remote_state.network_tfstate.outputs.nic_id

  vm_key_name = var.vm_key_name
}
