terraform {
  backend "local" {
    path = "/var/lib/opentofu/servacho-infrastructure.tfstate"
  }

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.46.0"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "~> 5.11.0"
    }
  }
}

provider "vault" {}

data "vault_kv_secret_v2" "proxmox" {
  mount = "secret"
  name  = "proxmox"
}

provider "proxmox" {
  endpoint  = "https://192.168.5.10:8006/"
  api_token = data.vault_kv_secret_v2.proxmox.data["api_token"]
  insecure  = true
}