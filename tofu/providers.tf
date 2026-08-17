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
  # Setting temporary access token, which is to be revolked very soon after OpenBao configuration.
  api_token = "tofu-provisioner@pve!token=e57274fa-82b5-4f53-8e35-42635b94c98c"
  insecure  = true
}