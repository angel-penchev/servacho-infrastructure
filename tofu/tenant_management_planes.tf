# One management plane per organisation's pool, as docs/guide.md Phase 5
# intends: a VM in the organisation's pool on its VLAN, holding its OpenTofu
# state, its OpenBao and, later, the runner for its infrastructure repository.
# Everything from an empty VM to an unsealed OpenBao happens here, from the
# root plane, with no command run by hand on Proxmox or on the plane:
#
#   1. the installer ISO (nixos/images/installer.nix) is built and uploaded
#      through the Proxmox API (infrastructure-reusables' installer-iso);
#   2. each plane's VM boots it from an empty disk, nixos-anywhere installs the
#      plane's host configuration, and the plane comes up on its static .15
#      address, deployed like the root plane from then on (nixos-vm);
#   3. scripts/tenant-plane-openbao.sh initialises the plane's OpenBao, keeps
#      its keys in the root OpenBao and seeds it with the organisation's
#      Proxmox token.
#
# docs/tenant-management-planes.md has the rest. Nothing here exists until
# tenant_management_planes_enabled is flipped; until then every count and
# for_each below is empty and this file plans as no changes.

locals {
  tenant_management_planes_enabled = false

  # A management plane takes .15 of its VLAN; VM id rule: the VLAN followed by
  # the zero-padded last octet. The prefix and gateway live in the host files
  # under nixos/hosts/.
  tenant_management_planes = {
    qoax-community = {
      host                 = "qoax-community-management-plane"
      vm_id                = 10015
      pool_id              = proxmox_virtual_environment_pool.pool_qoax_community.id
      vlan                 = 10
      address              = "192.168.10.15"
      proxmox_token_secret = vault_kv_secret_v2.qoax_community_vault_secret.name
    }
    fmicodes = {
      host                 = "fmicodes-management-plane"
      vm_id                = 12015
      pool_id              = proxmox_virtual_environment_pool.pool_fmicodes.id
      vlan                 = 12
      address              = "192.168.12.15"
      proxmox_token_secret = vault_kv_secret_v2.fmicodes_vault_secret.name
    }
  }

  enabled_tenant_management_planes = (
    local.tenant_management_planes_enabled ? local.tenant_management_planes : {}
  )
  # Built once for all planes, and only when there are any.
  tenant_management_plane_tools = length(local.enabled_tenant_management_planes) > 0 ? 1 : 0

  nixos_flake = abspath("${path.module}/../nixos")
}

module "installer_iso" {
  count  = local.tenant_management_plane_tools
  source = "github.com/angel-penchev/infrastructure-reusables//tofu/modules/installer-iso?ref=v0.1.0"

  flake_attr = "${local.nixos_flake}#installer-iso"
  iso_name   = "servacho-installer"
  node_name  = "Servacho-Gosho"
}

module "tenant_management_plane" {
  for_each = local.enabled_tenant_management_planes
  source   = "github.com/angel-penchev/infrastructure-reusables//tofu/modules/nixos-vm?ref=v0.1.0"

  name             = each.value.host
  node_name        = "Servacho-Gosho"
  vm_id            = each.value.vm_id
  pool_id          = each.value.pool_id
  tags             = ["nixos", "management-plane", each.key]
  vlan_id          = each.value.vlan
  installer_iso_id = module.installer_iso[0].file_id
  flake            = local.nixos_flake
  host             = each.value.host
  address          = each.value.address
  ssh_private_key  = data.vault_kv_secret_v2.management_plane_ssh.data["private_key"]
}

module "openbao_cli" {
  count  = local.tenant_management_plane_tools
  source = "github.com/nix-community/nixos-anywhere//terraform/nix-build?ref=1.13.0"

  attribute = "${local.nixos_flake}#openbao"
}

# Once per installation of a plane. The root OpenBao's address and token come
# from the workflow's environment, as for the vault provider.
resource "terraform_data" "tenant_management_plane_openbao" {
  for_each = local.enabled_tenant_management_planes

  triggers_replace = [module.tenant_management_plane[each.key].installation_id]

  provisioner "local-exec" {
    command = "${abspath("${path.module}/../scripts/tenant-plane-openbao.sh")} bootstrap"
    environment = {
      BAO                  = "${module.openbao_cli[0].result.out}/bin/bao"
      TENANT               = each.key
      TARGET_HOST          = each.value.address
      PROXMOX_TOKEN_SECRET = each.value.proxmox_token_secret
    }
  }

  depends_on = [module.tenant_management_plane]
}
