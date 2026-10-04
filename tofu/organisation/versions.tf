terraform {
  required_providers {
    proxmox = {
      source = "bpg/proxmox"
    }
    vault = {
      source = "hashicorp/vault"
    }
    tls = {
      source = "hashicorp/tls"
    }
  }
}
