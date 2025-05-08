provider "azurerm" {
  features {}
}

terraform {
  backend "azurerm" {
    resource_group_name  = "gogs-admin"
    storage_account_name = "terraformwow"
    container_name       = "terraform-backend-wow"
    key                  = "infra/db/terraform.tfstate"
  }
}

module "network" {
  source = "../../../modules/azure/db"

  rsg_name          = data.terraform_remote_state.network_tfstate.outputs.rsg_name
  rsg_location      = data.terraform_remote_state.network_tfstate.outputs.rsg_location
  private_subnet_id = data.terraform_remote_state.network_tfstate.outputs.private_subnet_id
  vnet_id           = data.terraform_remote_state.network_tfstate.outputs.vnet_id

  db_name     = var.db_name
  db_user     = var.db_user
  db_password = var.db_password
}
