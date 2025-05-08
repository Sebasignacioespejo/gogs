# Data from network

data "aws_s3_object" "network_tfstate" {
  bucket = "terraform-backend-wow"
  key    = "infra/network/terraform.tfstate"
}

# Security Group

resource "aws_security_group" "rds_sg" {
  name        = "rds_sg"
  description = "Security group for RDS"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Subnet Group

resource "aws_db_subnet_group" "rds_subnet_group" {
  name       = "main-subnet-group"
  subnet_ids = [var.private_subnet_a_id, var.private_subnet_b_id]
}

# RDS

resource "aws_db_instance" "gogs_db" {
  identifier             = "gogs-db"
  engine                 = "postgres"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  username               = var.db_user
  password               = var.db_password
  db_name                = var.db_name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  db_subnet_group_name   = aws_db_subnet_group.rds_subnet_group.name
  skip_final_snapshot    = true
  publicly_accessible    = false
}
