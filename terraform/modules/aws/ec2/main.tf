# Security Group

resource "aws_security_group" "ec2_sg" {
  name        = "ec2_sg"
  description = "Security group for Gogs EC2"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.control_ip}/32"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.agent_ip}/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# EC2

resource "aws_instance" "gogs_instance" {
  ami                    = var.ec2_ami
  instance_type          = "t2.micro"
  subnet_id              = var.public_subnet_id
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  key_name               = var.ec2_key_name

  root_block_device {
    volume_size = 30    # Tamaño en GB
    volume_type = "gp2" # Tipo de volumen (gp2, gp3, etc)
  }

  tags = {
    Name = "gogs-EC2"
  }
}
