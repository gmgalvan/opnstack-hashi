# variables.pkr.hcl

# AWS Configuration
variable "aws_region" {
  type        = string
  description = "AWS region for ECR"
  default     = "us-east-1"
}

variable "aws_account_id" {
  type        = string
  description = "AWS Account ID"

  validation {
    condition     = can(regex("^[0-9]{12}$", var.aws_account_id))
    error_message = "AWS Account ID must be exactly 12 digits."
  }
}

# ECR Configuration
variable "ecr_repository" {
  type        = string
  description = "ECR repository name"
  default     = "nginx-app"
}

variable "image_tags" {
  type        = list(string)
  description = "List of tags for the Docker image"
  default     = ["latest"]
}

# Build Configuration
variable "base_image" {
  type        = string
  description = "Base Docker image"
  default     = "ubuntu:22.04"
}

variable "nginx_version" {
  type        = string
  description = "Nginx version to install"
  default     = "latest"
}