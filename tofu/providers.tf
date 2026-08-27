terraform {
  backend "local" {
    path = "/var/lib/opentofu/servacho-infrastructure.tfstate"
  }

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.69.0"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "~> 5.11.0"
    }
  }
}

provider "vault" {
  address = "http://127.0.0.1:8200"
}

data "vault_kv_secret_v2" "proxmox_credentials" {
  mount = "secret"
  name  = "proxmox"
}

provider "proxmox" {
  endpoint  = "https://192.168.5.10:8006/"
  api_token = data.vault_kv_secret_v2.proxmox_credentials.data["api_token"]
  insecure  = true
}
