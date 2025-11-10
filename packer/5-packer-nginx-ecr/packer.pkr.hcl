# packer.pkr.hcl
packer {
  required_version = ">= 1.9.0"

  required_plugins {
    docker = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/docker"
    }
  }
}