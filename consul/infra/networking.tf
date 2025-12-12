# VPC
resource "aws_vpc" "consul_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "consul-vpc"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "consul_igw" {
  vpc_id = aws_vpc.consul_vpc.id

  tags = {
    Name = "consul-igw"
  }
}

# Public Subnet
resource "aws_subnet" "consul_subnet" {
  vpc_id                  = aws_vpc.consul_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "consul-subnet"
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

# Route Table
resource "aws_route_table" "consul_rt" {
  vpc_id = aws_vpc.consul_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.consul_igw.id
  }

  tags = {
    Name = "consul-rt"
  }
}

resource "aws_route_table_association" "consul_rta" {
  subnet_id      = aws_subnet.consul_subnet.id
  route_table_id = aws_route_table.consul_rt.id
}