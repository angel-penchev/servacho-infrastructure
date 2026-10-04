# An organisation on servacho: its Proxmox pool, the OpenTofu user and token
# that can act only inside that pool, and a copy of the token in the root
# OpenBao. plane.tf adds its management plane once it has one.
#
# Besides the pool, the user can do exactly what creating a VM there takes:
# allocate disks on the VM storage, keep ISO images (its installer) in a
# storage of its own, and put a network card on its own VLAN.

resource "proxmox_virtual_environment_pool" "this" {
  pool_id = "pool-${var.id}"
  comment = "Isolated Resource Pool for ${var.name} Infrastructure"
}

# A directory storage for ISO images only. The pinned provider has no storage
# resource, so the script makes it through the Proxmox API with the root
# token. Removing the organisation removes the definition only if this is
# destroyed while still in the configuration (tofu destroy -target); the files
# stay on the node either way.
resource "terraform_data" "iso_storage" {
  input = {
    storage  = "iso-${var.id}"
    path     = "/var/lib/organisation-isos/${var.id}"
    endpoint = var.proxmox_endpoint
  }

  provisioner "local-exec" {
    command = "${abspath("${path.module}/../../scripts/organisation-iso-storage.sh")} create"
    environment = {
      PROXMOX_ENDPOINT = self.input.endpoint
      STORAGE          = self.input.storage
      STORAGE_PATH     = self.input.path
    }
  }

  provisioner "local-exec" {
    when    = destroy
    command = "${abspath("${path.module}/../../scripts/organisation-iso-storage.sh")} destroy"
    environment = {
      PROXMOX_ENDPOINT = self.input.endpoint
      STORAGE          = self.input.storage
      STORAGE_PATH     = self.input.path
    }
  }
}

resource "proxmox_virtual_environment_user" "tofu" {
  user_id = "tofu-${var.id}@pve"
  comment = "${var.name} IaC Account"
  acl {
    path      = "/pool/${proxmox_virtual_environment_pool.this.pool_id}"
    propagate = true
    role_id   = var.roles.pool
  }
  acl {
    path    = "/storage/${var.disk_storage}"
    role_id = var.roles.disks
  }
  acl {
    path    = "/storage/${terraform_data.iso_storage.output.storage}"
    role_id = var.roles.isos
  }
  # Proxmox checks a tagged network card against the bridge's VLAN path, so
  # this is the organisation's VLAN and nothing else on the bridge.
  acl {
    path    = "/sdn/zones/localnetwork/${var.bridge}/${var.vlan}"
    role_id = var.roles.network
  }
}

resource "proxmox_virtual_environment_user_token" "tofu" {
  comment               = "${var.name} Automation Token"
  user_id               = proxmox_virtual_environment_user.tofu.user_id
  token_name            = "tofu-provisioner"
  privileges_separation = false
}

resource "vault_kv_secret_v2" "proxmox_token" {
  mount = "secret"
  name  = "proxmox/${replace(var.id, "-", "_")}_token"
  data_json = jsonencode({
    api_token = proxmox_virtual_environment_user_token.tofu.value
  })
}
