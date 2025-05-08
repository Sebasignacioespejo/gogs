# Healthchecks

resource "aws_route53_health_check" "aws" {
  ip_address        = var.ec2_ip
  type              = "HTTP"
  resource_path     = "/healthcheck"
  port              = 3000
  failure_threshold = 3
}

resource "aws_route53_health_check" "azure" {
  ip_address        = var.vm_ip
  type              = "HTTP"
  resource_path     = "/healthcheck"
  port              = 3000
  failure_threshold = 3
}

# DNS Records

resource "aws_route53_record" "aws_primary" {
  zone_id = var.hosted_zone_id
  name    = "malwaremasters.online"
  type    = "A"
  ttl     = 60
  records = [var.ec2_ip]

  set_identifier = "aws"

  failover_routing_policy {
    type = "PRIMARY"
  }

  health_check_id = aws_route53_health_check.aws.id
}

resource "aws_route53_record" "azure_secondary" {
  zone_id = var.hosted_zone_id
  name    = "malwaremasters.online"
  type    = "A"
  ttl     = 60
  records = [var.vm_ip]

  set_identifier = "azure"

  failover_routing_policy {
    type = "SECONDARY"
  }

  health_check_id = aws_route53_health_check.azure.id
}
