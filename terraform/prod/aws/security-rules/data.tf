# Data from ec2

data "aws_s3_object" "ec2_tfstate" {
  bucket = "terraform-backend-wow"
  key    = "infra/ec2/terraform.tfstate"
}

# Data from rds

data "aws_s3_object" "rds_tfstate" {
  bucket = "terraform-backend-wow"
  key    = "infra/rds/terraform.tfstate"
}
