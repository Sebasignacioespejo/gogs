provider "aws" {
  region = "us-east-2"
}

terraform {
  backend "s3" {
    bucket = "terraform-backend-wow"
    key    = "infra/route53/terraform.tfstate"
    region = "us-east-2"
  }
}

locals {
  ec2_tfstate = jsondecode(data.aws_s3_object.ec2_tfstate.body)
}

module "ec2" {
  source = "../../../modules/aws/route53"

  hosted_zone_id = var.hosted_zone_id

  ec2_ip = local.ec2_tfstate.outputs.ec2_public_ip.value
  vm_ip  = data.terraform_remote_state.network_tfstate.outputs.vm_ip
}
