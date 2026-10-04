# The organisations on servacho, one organisation/ each: pool, OpenTofu user
# and token, and once it has one, its management plane
# (docs/tenant-management-planes.md). What runs inside a pool belongs to the
# organisation's own infrastructure repository.

locals {
  # Creates the organisations' management planes. Until then nothing below
  # builds or uploads anything, and the planes plan as no changes.
  management_planes_enabled = false

  nixos_flake = abspath("${path.module}/../nixos")

  # The installer is rebuilt and uploaded again when the key it lets in or the
  # nixpkgs it is built from changes: a rotated key would otherwise leave an
  # installer no plane's install can log in to, and a newer nixpkgs brings its
  # kernel and SSH fixes. Anything else leaves the uploaded ISO alone.
  installer_generation = sha256(join("\n", [
    file("${path.module}/../nixos/hosts/servacho-managment-plane/deploy-key.pub"),
    jsondecode(file("${path.module}/../nixos/flake.lock")).nodes.nixpkgs.locked.rev,
  ]))

  # What every plane is built with.
  plane_tools = {
    installer_iso_id = local.management_planes_enabled ? module.installer_iso[0].file_id : null
    openbao_cli      = local.management_planes_enabled ? "${module.openbao_cli[0].result.out}/bin/bao" : null
    nixos_flake      = local.nixos_flake
  }
}

module "installer_iso" {
  count  = local.management_planes_enabled ? 1 : 0
  source = "github.com/angel-penchev/infrastructure-reusables//tofu/modules/installer-iso?ref=v0.1.0"

  flake_attr = "${local.nixos_flake}#installer-iso"
  iso_name   = "servacho-installer"
  node_name  = "Servacho-Gosho"
  generation = local.installer_generation
}

module "openbao_cli" {
  count  = local.management_planes_enabled ? 1 : 0
  source = "github.com/nix-community/nixos-anywhere//terraform/nix-build?ref=1.13.0"

  attribute = "${local.nixos_flake}#openbao"
}

# A management plane takes .15 of its VLAN; VM id rule: the VLAN followed by
# the zero-padded last octet. The prefix and gateway live in the host files
# under ../nixos/hosts/.

module "qoax_community" {
  source = "./organisation"

  id      = "qoax-community"
  name    = "Qoax Community"
  role_id = proxmox_virtual_environment_role.tofu_provisioner.role_id
  plane = local.management_planes_enabled ? {
    host    = "qoax-community-management-plane"
    vm_id   = 10015
    vlan    = 10
    address = "192.168.10.15"
  } : null

  installer_iso_id = local.plane_tools.installer_iso_id
  openbao_cli      = local.plane_tools.openbao_cli
  nixos_flake      = local.plane_tools.nixos_flake
  ssh_private_key  = data.vault_kv_secret_v2.management_plane_ssh.data["private_key"]
}

module "fmicodes" {
  source = "./organisation"

  id      = "fmicodes"
  name    = "FMI{Codes}"
  role_id = proxmox_virtual_environment_role.tofu_provisioner.role_id
  plane = local.management_planes_enabled ? {
    host    = "fmicodes-management-plane"
    vm_id   = 12015
    vlan    = 12
    address = "192.168.12.15"
  } : null

  installer_iso_id = local.plane_tools.installer_iso_id
  openbao_cli      = local.plane_tools.openbao_cli
  nixos_flake      = local.plane_tools.nixos_flake
  ssh_private_key  = data.vault_kv_secret_v2.management_plane_ssh.data["private_key"]
}

# No VLAN yet, so no plane; whether it gets one of its own is open.
module "qoax_community_broadcast" {
  source = "./organisation"

  id           = "qoax-community-broadcast"
  name         = "Qoax Community Broadcast"
  pool_comment = "Isolated Resource Pool for Qoax Community Broadcast Media"
  role_id      = proxmox_virtual_environment_role.tofu_provisioner.role_id
}

# Where the organisations' resources were before organisation/ existed.

moved {
  from = proxmox_virtual_environment_pool.pool_qoax_community
  to   = module.qoax_community.proxmox_virtual_environment_pool.this
}
moved {
  from = proxmox_virtual_environment_user.tofu_qoax_community
  to   = module.qoax_community.proxmox_virtual_environment_user.tofu
}
moved {
  from = proxmox_virtual_environment_user_token.qoax_community_token
  to   = module.qoax_community.proxmox_virtual_environment_user_token.tofu
}
moved {
  from = vault_kv_secret_v2.qoax_community_vault_secret
  to   = module.qoax_community.vault_kv_secret_v2.proxmox_token
}

moved {
  from = proxmox_virtual_environment_pool.pool_fmicodes
  to   = module.fmicodes.proxmox_virtual_environment_pool.this
}
moved {
  from = proxmox_virtual_environment_user.tofu_fmicodes
  to   = module.fmicodes.proxmox_virtual_environment_user.tofu
}
moved {
  from = proxmox_virtual_environment_user_token.fmicodes_token
  to   = module.fmicodes.proxmox_virtual_environment_user_token.tofu
}
moved {
  from = vault_kv_secret_v2.fmicodes_vault_secret
  to   = module.fmicodes.vault_kv_secret_v2.proxmox_token
}

moved {
  from = proxmox_virtual_environment_pool.pool_qoax_community_broadcast
  to   = module.qoax_community_broadcast.proxmox_virtual_environment_pool.this
}
moved {
  from = proxmox_virtual_environment_user.tofu_qoax_community_broadcast
  to   = module.qoax_community_broadcast.proxmox_virtual_environment_user.tofu
}
moved {
  from = proxmox_virtual_environment_user_token.qoax_community_broadcast_token
  to   = module.qoax_community_broadcast.proxmox_virtual_environment_user_token.tofu
}
moved {
  from = vault_kv_secret_v2.qoax_community_broadcast_vault_secret
  to   = module.qoax_community_broadcast.vault_kv_secret_v2.proxmox_token
}
