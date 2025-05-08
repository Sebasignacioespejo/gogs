# Data from network

data "aws_s3_object" "network_tfstate" {
  bucket = "terraform-backend-wow"
  key    = "infra/network/terraform.tfstate"
}
