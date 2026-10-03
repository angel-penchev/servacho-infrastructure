# One management plane per tenant pool, as docs/guide.md Phase 5 intends: a VM
# in the tenant's pool on the tenant's VLAN, holding that tenant's OpenTofu
# state, its OpenBao and, later, its runner. Everything from an empty VM to an
# unsealed OpenBao happens in this file, from the root plane, with no command
# run by hand on Proxmox or on the plane:
#
#   1. the installer ISO (nixos/images/installer.nix) is built here and uploaded
#      through the Proxmox API;
#   2. each VM boots it from an empty disk, takes a DHCP address and reports it
#      through the guest agent;
#   3. nixos-anywhere partitions the disk (disko) and installs the tenant's host
#      configuration, which comes up on the plane's static .15 address;
#   4. later changes to the host reach it the way the root plane's do;
#   5. scripts/tenant-plane-openbao.sh initialises the plane's OpenBao, keeps
#      its keys in the root OpenBao and seeds it with the tenant's Proxmox token.
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
  source = "github.com/nix-community/nixos-anywhere//terraform/nix-build?ref=1.13.0"

  attribute = "${local.nixos_flake}#installer-iso"
}

# An ISO goes through the Proxmox API; a disk image or a backup would need SSH
# to the node. The ISO only has to boot a new VM far enough for nixos-anywhere,
# which installs what the flake says at that moment, so a newer build is never
# uploaded over it: the planes keep it attached, and Proxmox will not start a
# VM whose ISO is gone.
resource "proxmox_virtual_environment_file" "installer_iso" {
  count        = local.tenant_management_plane_tools
  content_type = "iso"
  datastore_id = "local"
  node_name    = "Servacho-Gosho"

  source_file {
    path = "${module.installer_iso[0].result.out}/iso/servacho-installer.iso"
  }

  lifecycle {
    ignore_changes = [source_file]
  }
}

resource "proxmox_virtual_environment_vm" "tenant_management_plane" {
  for_each = local.enabled_tenant_management_planes

  name          = each.value.host
  node_name     = "Servacho-Gosho"
  vm_id         = each.value.vm_id
  pool_id       = each.value.pool_id
  tags          = ["nixos", "management-plane", each.key]
  scsi_hardware = "virtio-scsi-single"
  on_boot       = true

  # The disk first: until nixos-anywhere has put GRUB on it, SeaBIOS falls
  # through to the installer; afterwards it boots the installed system.
  boot_order = ["virtio0", "ide3"]

  # Creating the VM waits for the agent, so the installer's address is known
  # when the install below starts.
  agent {
    enabled = true
    timeout = "15m"
    trim    = false
  }

  cpu {
    cores = 2
    type  = "x86-64-v2-AES"
  }

  memory {
    dedicated = 4096
  }

  # Empty until disko partitions it (nixos/modules/proxmox-guest.nix).
  disk {
    interface    = "virtio0"
    datastore_id = "local-lvm"
    file_format  = "raw"
    size         = 32
    discard      = "ignore"
    iothread     = true
  }

  cdrom {
    enabled   = true
    file_id   = proxmox_virtual_environment_file.installer_iso[0].id
    interface = "ide3"
  }

  network_device {
    bridge   = "vmbr0"
    enabled  = true
    firewall = true
    model    = "virtio"
    vlan_id  = each.value.vlan
  }

  operating_system {
    type = "l26"
  }
}

module "tenant_management_plane_system" {
  for_each = local.enabled_tenant_management_planes
  source   = "github.com/nix-community/nixos-anywhere//terraform/nix-build?ref=1.13.0"

  attribute = "${local.nixos_flake}#nixosConfigurations.${each.value.host}.config.system.build.toplevel"
}

module "tenant_management_plane_disko" {
  for_each = local.enabled_tenant_management_planes
  source   = "github.com/nix-community/nixos-anywhere//terraform/nix-build?ref=1.13.0"

  attribute = "${local.nixos_flake}#nixosConfigurations.${each.value.host}.config.system.build.diskoScript"
}

module "tenant_management_plane_install" {
  for_each = local.enabled_tenant_management_planes
  source   = "github.com/nix-community/nixos-anywhere//terraform/install?ref=1.13.0"

  nixos_partitioner = module.tenant_management_plane_disko[each.key].result.out
  nixos_system      = module.tenant_management_plane_system[each.key].result.out
  # The installer's DHCP address, as the guest agent reports it. Only the
  # first install uses it; once the plane is on .15, a different value here
  # changes nothing, and the fallback keeps plans working while the VM is off.
  target_host = try(
    [for ip in flatten(proxmox_virtual_environment_vm.tenant_management_plane[each.key].ipv4_addresses) : ip if ip != "127.0.0.1"][0],
    each.value.address,
  )
  target_user     = "root"
  ssh_private_key = data.vault_kv_secret_v2.management_plane_ssh.data["private_key"]
  # Installs once per VM: only a new VM, and so a new id, installs again.
  instance_id = proxmox_virtual_environment_vm.tenant_management_plane[each.key].id
  # The installer is NixOS already, so there is nothing to kexec into.
  phases = ["disko", "install", "reboot"]
}

module "tenant_management_plane_deploy" {
  for_each = local.enabled_tenant_management_planes
  source   = "github.com/nix-community/nixos-anywhere//terraform/nixos-rebuild?ref=1.13.0"

  nixos_system    = module.tenant_management_plane_system[each.key].result.out
  target_host     = each.value.address
  target_user     = "root"
  ssh_private_key = data.vault_kv_secret_v2.management_plane_ssh.data["private_key"]

  depends_on = [module.tenant_management_plane_install]
}

module "openbao_cli" {
  count  = local.tenant_management_plane_tools
  source = "github.com/nix-community/nixos-anywhere//terraform/nix-build?ref=1.13.0"

  attribute = "${local.nixos_flake}#openbao"
}

# Once per VM. The root OpenBao's address and token come from the workflow's
# environment, as for the vault provider.
resource "terraform_data" "tenant_management_plane_openbao" {
  for_each = local.enabled_tenant_management_planes

  triggers_replace = [proxmox_virtual_environment_vm.tenant_management_plane[each.key].id]

  provisioner "local-exec" {
    command = "${abspath("${path.module}/../scripts/tenant-plane-openbao.sh")} bootstrap"
    environment = {
      BAO                  = "${module.openbao_cli[0].result.out}/bin/bao"
      TENANT               = each.key
      TARGET_HOST          = each.value.address
      PROXMOX_TOKEN_SECRET = each.value.proxmox_token_secret
    }
  }

  depends_on = [module.tenant_management_plane_deploy]
}
