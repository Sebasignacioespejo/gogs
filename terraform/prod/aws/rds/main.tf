provider "aws" {
  region = "us-east-2"
}

terraform {
  backend "s3" {
    bucket = "terraform-backend-wow"
    key    = "infra/rds/terraform.tfstate"
    region = "us-east-2"
  }
}

locals {
  network_tfstate = jsondecode(data.aws_s3_object.network_tfstate.body)
}

module "rds" {
  source = "../../../modules/aws/rds"

  db_user     = var.db_user
  db_password = var.db_password
  db_name     = var.db_name

  vpc_id              = local.network_tfstate.outputs.vpc_id.value
  private_subnet_a_id = local.network_tfstate.outputs.private_subnet_a_id.value
  private_subnet_b_id = local.network_tfstate.outputs.private_subnet_b_id.value
}
