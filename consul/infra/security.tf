
# Security Group for Consul
resource "aws_security_group" "consul_sg" {
  name        = "consul-sg"
  description = "Security group for Consul cluster"
  vpc_id      = aws_vpc.consul_vpc.id

  # SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH access"
  }

### ---- Consul ports security starts here ---- ###
  # Consul Server RPC
  ingress {
    from_port   = 8300
    to_port     = 8300
    protocol    = "tcp"
    self        = true
    description = "Consul server RPC"
  }

  # Consul Serf LAN
  ingress {
    from_port   = 8301
    to_port     = 8301
    protocol    = "tcp"
    self        = true
    description = "Consul Serf LAN TCP"
  }

  ingress {
    from_port   = 8301
    to_port     = 8301
    protocol    = "udp"
    self        = true
    description = "Consul Serf LAN UDP"
  }

  # Consul Serf WAN
  ingress {
    from_port   = 8302
    to_port     = 8302
    protocol    = "tcp"
    self        = true
    description = "Consul Serf WAN TCP"
  }

  ingress {
    from_port   = 8302
    to_port     = 8302
    protocol    = "udp"
    self        = true
    description = "Consul Serf WAN UDP"
  }

  # Consul HTTP API
  ingress {
    from_port   = 8500
    to_port     = 8500
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Consul HTTP API"
  }

  # Consul DNS
  ingress {
    from_port   = 8600
    to_port     = 8600
    protocol    = "tcp"
    self        = true
    description = "Consul DNS TCP"
  }

  ingress {
    from_port   = 8600
    to_port     = 8600
    protocol    = "udp"
    self        = true
    description = "Consul DNS UDP"
  }

### ---- Consul ports security ends here ---- ###

  # Application ports (for testing)
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    self        = true
    description = "Application port 8080 (within cluster)"
  }

  ingress {
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    self        = true
    description = "Application port 9090 (within cluster)"
  }

  # PostgreSQL
  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    self        = true
    description = "PostgreSQL (within cluster)"
  }

  # Egress - allow all outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }



  tags = {
    Name = "consul-sg"
  }
}