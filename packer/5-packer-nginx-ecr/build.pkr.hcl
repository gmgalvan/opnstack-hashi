locals {
  timestamp = regex_replace(timestamp(), "[- TZ:]", "")
  ecr_url   = "${var.aws_account_id}.dkr.ecr.${var.aws_region}.amazonaws.com"
  full_repo = "${local.ecr_url}/${var.ecr_repository}"
}

build {
  name    = "nginx-docker-build"
  sources = ["source.docker.nginx"]

  # Provisioning
  provisioner "shell" {
    script = "${path.root}/scripts/install-nginx.sh"
    environment_vars = [
      "NGINX_VERSION=${var.nginx_version}",
      "DEBIAN_FRONTEND=noninteractive"
    ]
  }

  # Opcional: copiar archivos de configuración
  provisioner "file" {
    source      = "${path.root}/files/nginx.conf"
    destination = "/tmp/nginx.conf"
  }

  provisioner "shell" {
    inline = [
      "mv /tmp/nginx.conf /etc/nginx/nginx.conf",
      "nginx -t"
    ]
  }

  # Post-processing
  post-processors {
    post-processor "docker-tag" {
      repository = local.full_repo
      tags       = concat(var.image_tags, ["build-${local.timestamp}"])
    }

    post-processor "docker-push" {
      ecr_login    = true
      login_server = "https://${local.ecr_url}"
    }
  }
}