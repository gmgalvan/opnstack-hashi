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
  type = string
}

variable "ecr_repository" {
  type    = string
  default = "nodejs-app"
}

variable "image_tag" {
  type    = string
  default = "latest"
}

source "null" "nodejs" {
  communicator = "none"
}

build {
  name = "nodejs-docker-build"
  
  sources = ["source.null.nodejs"]
  
  # 1. Construir la imagen desde Dockerfile
  provisioner "shell-local" {
    inline = [
      "echo '🔨 Construyendo imagen desde Dockerfile...'",
      "docker build -t ${var.ecr_repository}:${var.image_tag} ."
    ]
  }
  
  # 2. Etiquetar para ECR
  provisioner "shell-local" {
    inline = [
      "echo '🏷️  Etiquetando para ECR...'",
      "docker tag ${var.ecr_repository}:${var.image_tag} ${var.aws_account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/${var.ecr_repository}:${var.image_tag}",
      "docker tag ${var.ecr_repository}:${var.image_tag} ${var.aws_account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/${var.ecr_repository}:v1.0"
    ]
  }
  
  # 3. Login en ECR
  provisioner "shell-local" {
    inline = [
      "echo '🔐 Login en ECR...'",
      "aws ecr get-login-password --region ${var.aws_region} | docker login --username AWS --password-stdin ${var.aws_account_id}.dkr.ecr.${var.aws_region}.amazonaws.com"
    ]
  }
  
  # 4. Push a ECR
  provisioner "shell-local" {
    inline = [
      "echo '⬆️  Subiendo a ECR...'",
      "docker push ${var.aws_account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/${var.ecr_repository}:${var.image_tag}",
      "docker push ${var.aws_account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/${var.ecr_repository}:v1.0",
      "echo '✅ ¡Imagen subida exitosamente!'"
    ]
  }
}