terraform {
  backend "local" {
    path = "/var/lib/opentofu/servacho-infrastructure.tfstate"
  }

  required_providers {
    unifi = {
      source  = "ubiquiti-community/unifi"
      version = "~> 0.55.0"
    }
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

data "vault_kv_secret_v2" "unifi_credentials" {
  mount = "secret"
  name  = "unifi"
}

provider "unifi" {
  username       = data.vault_kv_secret_v2.unifi_credentials.data["username"]
  password       = data.vault_kv_secret_v2.unifi_credentials.data["password"]
  api_url        = "https://192.168.1.1"
  allow_insecure = true
}

data "vault_kv_secret_v2" "radius_profile" {
  mount = "secret"
  name  = "unifi/radius/profile"
}

data "vault_kv_secret_v2" "radius_users" {
  mount = "secret"
  name  = "unifi/radius/users"
}

data "vault_kv_secret_v2" "wlan_passphrases" {
  mount = "secret"
  name  = "unifi/wlan/passphrases"
}

data "vault_kv_secret_v2" "wireguard_server" {
  mount = "secret"
  name  = "unifi/vpn/wireguard"
}
