terraform {
  backend "local" {
    path = "/var/lib/opentofu/servacho-infrastructure.tfstate"
  }

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.46.0"
    }
  }
}

provider "proxmox" {
  endpoint  = "https://192.168.5.10:8006/"
  api_token = "tofu-provisioner@pve!token=(token)"
  insecure  = true
}