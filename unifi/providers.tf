terraform {
  backend "local" {
    path = "/var/lib/opentofu/unifi-infrastructure.tfstate"
  }

  required_providers {
    unifi = {
      source  = "paultyng/unifi"
      version = "~> 0.41.0"
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
