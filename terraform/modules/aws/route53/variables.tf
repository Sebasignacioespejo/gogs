variable "ec2_ip" {
  type = string
}

variable "vm_ip" {
  type = string
}

variable "hosted_zone_id" {
  type = string
}

variable "alert_emails" {
  type = list(string)
}
