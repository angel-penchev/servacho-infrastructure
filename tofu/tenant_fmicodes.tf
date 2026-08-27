resource "proxmox_virtual_environment_pool" "pool_fmicodes" {
  pool_id = "pool-fmicodes"
  comment = "Isolated Resource Pool for FMI{Codes} Infrastructure"
}

resource "proxmox_virtual_environment_user" "tofu_fmicodes" {
  user_id = "tofu-fmicodes@pve"
  lifecycle {
    ignore_changes = [acl]
  }
  comment = "FMI{Codes} IaC Account"
  acl {
    path      = "/pool/${proxmox_virtual_environment_pool.pool_fmicodes.pool_id}"
    propagate = true
    role_id   = proxmox_virtual_environment_role.tofu_provisioner.role_id
  }
}

resource "proxmox_virtual_environment_user_token" "fmicodes_token" {
  comment               = "FMI{Codes} Automation Token"
  user_id               = proxmox_virtual_environment_user.tofu_fmicodes.user_id
  token_name            = "tofu-provisioner"
  privileges_separation = false
}

resource "vault_kv_secret_v2" "fmicodes_vault_secret" {
  mount = "secret"
  name  = "proxmox/fmicodes_token"
  data_json = jsonencode({
    api_token = proxmox_virtual_environment_user_token.fmicodes_token.value
  })
}
