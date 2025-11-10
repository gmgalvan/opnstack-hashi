// nginx-ami.pkr.hcl
packer {
  required_plugins {
    amazon = {
      source  = "github.com/hashicorp/amazon"
      version = ">= 1.2.0"
    }
  }
}

# --- VARIABLES ---
variable "aws_region" {
  type        = string
  description = "Región AWS donde se construirá la AMI"
  default     = "us-east-1"
}

variable "instance_type" {
  type        = string
  description = "Tipo de instancia temporal para el build"
  default     = "t3.micro"
}

variable "ami_name_prefix" {
  type        = string
  description = "Prefijo para el nombre de la AMI"
  default     = "nginx-hello"
}

variable "html_title" {
  type    = string
  default = "¡Hola Mundo desde Nginx!"
}

variable "html_message" {
  type    = string
  default = "AMI creada con HashiCorp Packer + Nginx"
}

variable "secret_banner" {
  type        = string
  description = "Solo para demostrar sensitive; no se imprime en logs"
  sensitive   = true
  default     = ""
}

# --- LOCALS (dinámicos) ---
locals {
  build_ts = formatdate("YYYYMMDD-HHmmss", timestamp())
  ami_name = "${var.ami_name_prefix}-${local.build_ts}"
}

# --- SOURCE ---
source "amazon-ebs" "al2" {
  region        = var.aws_region
  instance_type = var.instance_type
  ssh_username  = "ec2-user"

  source_ami_filter {
    filters = {
      name                = "amzn2-ami-hvm-*-x86_64-gp2"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    owners      = ["137112412989"]
    most_recent = true
  }

  ami_name        = local.ami_name
  ami_description = "AMI con Nginx + sitio Hola Mundo"

  launch_block_device_mappings {
    device_name           = "/dev/xvda"
    volume_size           = 8
    volume_type           = "gp3"
    delete_on_termination = true
  }

  tags = {
    Name    = local.ami_name
    BuiltBy = "Packer"
    Role    = "nginx-hello"
  }

}

# --- BUILD ---
build {
  name    = "nginx-hello"
  sources = ["source.amazon-ebs.al2"]

  provisioner "shell" {
    inline = [
      "sudo yum -y update",
      "sudo amazon-linux-extras enable nginx1 || true",
      "sudo yum -y install nginx",
      "sudo systemctl enable nginx",
      "sudo systemctl start nginx"
    ]
  }

  provisioner "file" {
    source      = "site"
    destination = "/tmp/site"
  }

  provisioner "shell" {
    inline = [
      "set -euo pipefail",
      "test -d /tmp/site || (echo 'ERROR: /tmp/site no existe; ¿se subió la carpeta site/?' && exit 1)",
      "sudo mkdir -p /usr/share/nginx/html",
      "sudo rm -rf /usr/share/nginx/html/*",
      "sudo cp -a /tmp/site/. /usr/share/nginx/html/",
      "sudo sed -i 's|__TITLE__|${var.html_title}|g' /usr/share/nginx/html/index.html || true",
      "sudo sed -i 's|__MESSAGE__|${var.html_message}|g' /usr/share/nginx/html/index.html || true",
      "sudo chown -R nginx:nginx /usr/share/nginx/html",
      "sudo systemctl restart nginx",
      "echo 'Sitio copiado a /usr/share/nginx/html correctamente.'"
    ]
  }


  post-processor "manifest" {
    output     = "manifest.json"
    strip_path = true
  }
}
