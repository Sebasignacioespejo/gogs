variable "ec2_ami" {
  description = "AMI ID for EC2"
  type        = string
}

variable "ec2_key_name" {
  description = "EC2 SSH key name"
  type        = string
}

variable "control_ip" {
  type = string
}

variable "agent_ip" {
  type = string
}
