provider "aws" {
  region = "us-east-2"
}

terraform {
  backend "s3" {
    bucket = "terraform-backend-wow"
    key    = "infra/security-rules/terraform.tfstate"
    region = "us-east-2"
  }
}

locals {
  ec2_tfstate = jsondecode(data.aws_s3_object.ec2_tfstate.body)
  rds_tfstate = jsondecode(data.aws_s3_object.rds_tfstate.body)
}

module "security-rules" {
  source = "../../../modules/aws/security-rules"

  ec2_sg_id = local.ec2_tfstate.outputs.ec2_sg_id.value
  rds_sg_id = local.rds_tfstate.outputs.rds_sg_id.value
}
