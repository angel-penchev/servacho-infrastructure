resource "proxmox_virtual_environment_pool" "pool_qoax_community" {
  pool_id = "pool-qoax-community"
  comment = "Isolated Resource Pool for Qoax Community Infrastructure"
}

resource "proxmox_virtual_environment_user" "tofu_qoax_community" {
  user_id = "tofu-qoax-community@pve"
  comment = "Qoax Community IaC Account"
}

resource "proxmox_virtual_environment_acl" "qoax_community_pool_acl" {
  path      = "/pool/${proxmox_virtual_environment_pool.pool_qoax_community.pool_id}"
  propagate = true
  role_id   = proxmox_virtual_environment_role.tofu_provisioner.role_id
  user_id   = proxmox_virtual_environment_user.tofu_qoax_community.user_id
}

resource "proxmox_virtual_environment_user_token" "qoax_community_token" {
  comment               = "Qoax Community Automation Token"
  user_id               = proxmox_virtual_environment_user.tofu_qoax_community.user_id
  token_name            = "tofu-provisioner"
  privileges_separation = false
}

resource "vault_kv_secret_v2" "qoax_community_vault_secret" {
  mount = "secret"
  name  = "proxmox/qoax_community_token"
  data_json = jsonencode({
    api_token = proxmox_virtual_environment_user_token.qoax_community_token.value
  })
}
