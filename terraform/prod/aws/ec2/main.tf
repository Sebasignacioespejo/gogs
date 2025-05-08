provider "aws" {
  region = "us-east-2"
}

terraform {
  backend "s3" {
    bucket = "terraform-backend-wow"
    key    = "infra/ec2/terraform.tfstate"
    region = "us-east-2"
  }
}

locals {
  network_tfstate = jsondecode(data.aws_s3_object.network_tfstate.body)
}

module "ec2" {
  source = "../../../modules/aws/ec2"

  ec2_ami      = var.ec2_ami
  ec2_key_name = var.ec2_key_name
  control_ip   = var.control_ip
  agent_ip     = var.agent_ip

  public_subnet_id = local.network_tfstate.outputs.public_subnet_id.value
  vpc_id           = local.network_tfstate.outputs.vpc_id.value
}
