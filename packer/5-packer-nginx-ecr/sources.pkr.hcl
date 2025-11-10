# sources.pkr.hcl

source "docker" "nginx" {
  image  = var.base_image
  commit = true

  changes = [
    "EXPOSE 80",
    "CMD [\"nginx\", \"-g\", \"daemon off;\"]",
    "LABEL maintainer='DevOps Team'",
    "LABEL version='1.0'",
    "LABEL description='Nginx web server'"
  ]
}