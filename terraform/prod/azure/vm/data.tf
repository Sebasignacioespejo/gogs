data "terraform_remote_state" "network_tfstate" {
  backend = "azurerm"

  config = {
    resource_group_name  = "gogs-admin"
    storage_account_name = "terraformwow"
    container_name       = "terraform-backend-wow"
    key                  = "infra/network/terraform.tfstate"
  }
}
