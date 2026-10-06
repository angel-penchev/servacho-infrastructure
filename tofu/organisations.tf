# The organisations on servacho, one organisation/ each: pool, OpenTofu user
# and token, and once it has one, its management plane
# (docs/tenant-management-planes.md). What runs inside a pool belongs to the
# organisation's own infrastructure repository.

locals {
  # Creates the organisations' management planes. Turned off, nothing below
  # builds or uploads anything, and the planes plan as no changes.
  management_planes_enabled = true

  nixos_flake = abspath("${path.module}/../nixos")

  # The organisation's OpenTofu user's roles (roles.tf).
  organisation_roles = {
    pool    = proxmox_virtual_environment_role.tofu_provisioner.role_id
    disks   = proxmox_virtual_environment_role.tofu_disks.role_id
    isos    = proxmox_virtual_environment_role.tofu_isos.role_id
    network = proxmox_virtual_environment_role.tofu_network.role_id
  }

  # What every plane is built with.
  plane_tools = {
    installer_iso_id = local.management_planes_enabled ? module.installer_iso[0].file_id : null
    openbao_cli      = local.management_planes_enabled ? "${module.openbao_cli[0].result.out}/bin/bao" : null
    nixos_flake      = local.nixos_flake
  }
}

module "installer_iso" {
  count  = local.management_planes_enabled ? 1 : 0
  source = "github.com/angel-penchev/infrastructure-reusables//tofu/modules/installer-iso?ref=v0.3.0"

  # Rebuilt and uploaded again whenever anything that goes into it changes
  # (nixpkgs, the deploy key, the installer module), under a new name; the
  # planes are moved onto it and the old one is deleted.
  flake_attr = "${local.nixos_flake}#installer-iso"
  iso_name   = "servacho-installer"
  node_name  = "Servacho-Gosho"
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

  id    = "qoax-community"
  name  = "Qoax Community"
  vlan  = 10
  roles = local.organisation_roles
  plane = local.management_planes_enabled ? {
    host    = "qoax-community-management-plane"
    vm_id   = 10015
    address = "192.168.10.15"
  } : null

  installer_iso_id = local.plane_tools.installer_iso_id
  openbao_cli      = local.plane_tools.openbao_cli
  nixos_flake      = local.plane_tools.nixos_flake
  ssh_private_key  = data.vault_kv_secret_v2.management_plane_ssh.data["private_key"]
}

module "fmicodes" {
  source = "./organisation"

  id    = "fmicodes"
  name  = "FMI{Codes}"
  vlan  = 12
  roles = local.organisation_roles
  plane = local.management_planes_enabled ? {
    host    = "fmicodes-management-plane"
    vm_id   = 12015
    address = "192.168.12.15"
  } : null

  installer_iso_id = local.plane_tools.installer_iso_id
  openbao_cli      = local.plane_tools.openbao_cli
  nixos_flake      = local.plane_tools.nixos_flake
  ssh_private_key  = data.vault_kv_secret_v2.management_plane_ssh.data["private_key"]
}

# The public halves of the planes' deploy keys, for each organisation to
# commit to its repository (its installer and hosts let the plane in with it).
output "organisation_deploy_keys" {
  value = {
    for org in [module.qoax_community, module.fmicodes] :
    org.id => org.deploy_public_key
    if org.deploy_public_key != null
  }
}
