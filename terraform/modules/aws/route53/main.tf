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

# Alarm

resource "aws_sns_topic" "alerts" {
  name = "route53-alerts"
}

resource "aws_sns_topic_subscription" "email_alert" {
  for_each  = toset(var.alert_emails)
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = each.value
}

resource "aws_cloudwatch_metric_alarm" "route53_fail" {
  alarm_name          = "aws-primary-ip-down"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "HealthCheckStatus"
  namespace           = "AWS/Route53"
  period              = 60
  statistic           = "Minimum"
  threshold           = 1
  alarm_description   = "Primary IP Failed (health check)"
  dimensions = {
    HealthCheckId = aws_route53_health_check.aws.id
  }
  alarm_actions = [aws_sns_topic.alerts.arn]
}
