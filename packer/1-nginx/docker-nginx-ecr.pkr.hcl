packer {
  required_plugins {
    docker = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/docker"
    }
  }
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "aws_account_id" {
  type    = string
  default = "023890853822"
}

variable "ecr_repository" {
  type    = string
  default = "nginx-app"
}

source "docker" "nginx" {
  image  = "ubuntu:22.04"
  commit = true
  changes = [
    "EXPOSE 80",
    "CMD [\"nginx\", \"-g\", \"daemon off;\"]"
  ]
}

build {
  sources = ["source.docker.nginx"]

  provisioner "shell" {
    inline = [
      "apt-get update",
      "apt-get install -y nginx",
      "echo 'daemon off;' >> /etc/nginx/nginx.conf",
      "rm -rf /var/lib/apt/lists/*"
    ]
  }

  post-processors {
    post-processor "docker-tag" {
      repository = "${var.aws_account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/${var.ecr_repository}"
      tags       = ["latest", "v1.0"]
    }

    post-processor "docker-push" {
      ecr_login    = true
      login_server = "https://${var.aws_account_id}.dkr.ecr.${var.aws_region}.amazonaws.com"
    }
  }
}

# packer
# variables
# soure
# build
  # hacemos referencia source
  # provisioner
  # post-processors