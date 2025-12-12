variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"
}

variable "key_name" {
  description = "SSH key pair name for EC2 instances"
  type        = string
  # You must provide this value
}

variable "consul_version" {
  description = "Consul version to install"
  type        = string
  default     = "1.17.0"
}

variable "datacenter" {
  description = "Consul datacenter name"
  type        = string
  default     = "dc1"
}

variable "environment" {
  description = "Environment tag"
  type        = string
  default     = "dev"
}
