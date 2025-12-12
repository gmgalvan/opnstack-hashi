

# Data source for latest Ubuntu AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}


# IAM Role for Consul EC2 instances (for cloud auto-join)
resource "aws_iam_role" "consul_role" {
  name = "consul-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "consul-role"
  }
}

# IAM Policy for EC2 instance discovery
resource "aws_iam_role_policy" "consul_policy" {
  name = "consul-ec2-policy"
  role = aws_iam_role.consul_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeTags"
        ]
        Resource = "*"
      }
    ]
  })
}

# IAM Instance Profile
resource "aws_iam_instance_profile" "consul_profile" {
  name = "consul-instance-profile"
  role = aws_iam_role.consul_role.name
}

# Generate a random Consul encryption key
resource "random_id" "consul_encrypt" {
  byte_length = 32
}

# Consul Server Instances
resource "aws_instance" "consul_server" {
  count                  = 3
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.consul_subnet.id
  vpc_security_group_ids = [aws_security_group.consul_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.consul_profile.name
  key_name               = var.key_name

  user_data = templatefile("${path.module}/scripts/consul_server.sh", {
    consul_version = var.consul_version
    datacenter     = var.datacenter
    encrypt_key    = random_id.consul_encrypt.b64_std
    server_count   = 3
  })

  tags = {
    Name        = "consul-server-${count.index + 1}"
    ConsulRole  = "server"
    Environment = var.environment
  }

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }
}

# Consul Client Instances
resource "aws_instance" "consul_client" {
  count                  = 2
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.consul_subnet.id
  vpc_security_group_ids = [aws_security_group.consul_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.consul_profile.name
  key_name               = var.key_name

  user_data = templatefile("${path.module}/scripts/consul_client.sh", {
    consul_version = var.consul_version
    datacenter     = var.datacenter
    encrypt_key    = random_id.consul_encrypt.b64_std
  })

  tags = {
    Name        = "consul-client-${count.index + 1}"
    ConsulRole  = "client"
    Environment = var.environment
  }

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }
}
