provider "aws" {
  region = "us-east-2"
}

terraform {
  backend "s3" {
    bucket = "terraform-backend-wow"
    key    = "infra/network/terraform.tfstate"
    region = "us-east-2"
  }
}

module "network" {
  source = "../../../modules/aws/network"
}
