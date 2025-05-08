# Data from ec2

data "aws_s3_object" "ec2_tfstate" {
  bucket = "terraform-backend-wow"
  key    = "infra/ec2/terraform.tfstate"
}

# Data from vm

data "terraform_remote_state" "network_tfstate" {
  backend = "azurerm"

  config = {
    resource_group_name  = "gogs-admin"
    storage_account_name = "terraformwow"
    container_name       = "terraform-backend-wow"
    key                  = "infra/network/terraform.tfstate"
  }
}
