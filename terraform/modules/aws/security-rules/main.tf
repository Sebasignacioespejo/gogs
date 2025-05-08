# Security Group Rules

resource "aws_security_group_rule" "rds_from_ec2" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = var.ec2_sg_id
  security_group_id        = var.rds_sg_id
}

resource "aws_security_group_rule" "ec2_from_rds" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = var.rds_sg_id
  security_group_id        = var.ec2_sg_id
}
