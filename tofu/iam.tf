# ==============================================================================
# IAM & RESOURCE POOL ISOLATION (Phase 4)
# ==============================================================================
# This file dictates the organizational boundaries within the Proxmox cluster.
# Each tenant gets a dedicated Resource Pool, IAM User, and automation Token.
# Tokens are pushed directly to Vault, meaning human operators never see them.
# ==============================================================================

# -------------------------------------------------------------
# 1. PERSONAL ISOLATION
# -------------------------------------------------------------
resource "proxmox_virtual_environment_pool" "pool_personal" {
  pool_id = "pool-personal"
  comment = "Isolated Resource Pool for Personal Infrastructure"
}

resource "proxmox_virtual_environment_user" "tofu_personal" {
  user_id = "tofu-personal@pve"
  comment = "Personal IaC Account"
}

resource "proxmox_acl" "personal_pool_acl" {
  path    = "/pool/${proxmox_virtual_environment_pool.pool_personal.pool_id}"
  role_id = proxmox_virtual_environment_role.tofu_provisioner.role_id
  user_id = proxmox_virtual_environment_user.tofu_personal.user_id
}

resource "proxmox_virtual_environment_user_token" "personal_token" {
  comment               = "Personal Automation Token"
  user_id               = proxmox_virtual_environment_user.tofu_personal.user_id
  token_name            = "tofu-provisioner"
  privileges_separation = false
}

resource "vault_kv_secret_v2" "personal_vault_secret" {
  mount = "secret"
  name  = "proxmox/personal_token"
  data_json = jsonencode({
    api_token = proxmox_virtual_environment_user_token.personal_token.value
  })
}

# -------------------------------------------------------------
# 2. QOAX COMMUNITY ISOLATION
# -------------------------------------------------------------
resource "proxmox_virtual_environment_pool" "pool_qoax_community" {
  pool_id = "pool-qoax-community"
  comment = "Isolated Resource Pool for Qoax Community Infrastructure"
}

resource "proxmox_virtual_environment_user" "tofu_qoax_community" {
  user_id = "tofu-qoax-community@pve"
  comment = "Qoax Community IaC Account"
}

resource "proxmox_acl" "qoax_community_pool_acl" {
  path    = "/pool/${proxmox_virtual_environment_pool.pool_qoax_community.pool_id}"
  role_id = proxmox_virtual_environment_role.tofu_provisioner.role_id
  user_id = proxmox_virtual_environment_user.tofu_qoax_community.user_id
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

# -------------------------------------------------------------
# 3. QOAX COMMUNITY BROADCAST ISOLATION
# -------------------------------------------------------------
resource "proxmox_virtual_environment_pool" "pool_qoax_community_broadcast" {
  pool_id = "pool-qoax-community-broadcast"
  comment = "Isolated Resource Pool for Qoax Community Broadcast Media"
}

resource "proxmox_virtual_environment_user" "tofu_qoax_community_broadcast" {
  user_id = "tofu-qoax-community-broadcast@pve"
  comment = "Qoax Community Broadcast IaC Account"
}

resource "proxmox_acl" "qoax_community_broadcast_pool_acl" {
  path    = "/pool/${proxmox_virtual_environment_pool.pool_qoax_community_broadcast.pool_id}"
  role_id = proxmox_virtual_environment_role.tofu_provisioner.role_id
  user_id = proxmox_virtual_environment_user.tofu_qoax_community_broadcast.user_id
}

resource "proxmox_virtual_environment_user_token" "qoax_community_broadcast_token" {
  comment               = "Qoax Community Broadcast Automation Token"
  user_id               = proxmox_virtual_environment_user.tofu_qoax_community_broadcast.user_id
  token_name            = "tofu-provisioner"
  privileges_separation = false
}

resource "vault_kv_secret_v2" "qoax_community_broadcast_vault_secret" {
  mount = "secret"
  name  = "proxmox/qoax_community_broadcast_token"
  data_json = jsonencode({
    api_token = proxmox_virtual_environment_user_token.qoax_community_broadcast_token.value
  })
}

# -------------------------------------------------------------
# 4. FMI{CODES} ISOLATION
# -------------------------------------------------------------
resource "proxmox_virtual_environment_pool" "pool_fmicodes" {
  pool_id = "pool-fmicodes"
  comment = "Isolated Resource Pool for FMI{Codes} Infrastructure"
}

resource "proxmox_virtual_environment_user" "tofu_fmicodes" {
  user_id = "tofu-fmicodes@pve"
  comment = "FMI{Codes} IaC Account"
}

resource "proxmox_acl" "fmicodes_pool_acl" {
  path    = "/pool/${proxmox_virtual_environment_pool.pool_fmicodes.pool_id}"
  role_id = proxmox_virtual_environment_role.tofu_provisioner.role_id
  user_id = proxmox_virtual_environment_user.tofu_fmicodes.user_id
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
