# An organisation on servacho: its Proxmox pool, the OpenTofu user and token
# that can act only inside that pool, and a copy of the token in the root
# OpenBao. plane.tf adds its management plane once it has one.

resource "proxmox_virtual_environment_pool" "this" {
  pool_id = "pool-${var.id}"
  comment = "Isolated Resource Pool for ${var.name} Infrastructure"
}

resource "proxmox_virtual_environment_user" "tofu" {
  user_id = "tofu-${var.id}@pve"
  comment = "${var.name} IaC Account"
  acl {
    path      = "/pool/${proxmox_virtual_environment_pool.this.pool_id}"
    propagate = true
    role_id   = var.role_id
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
