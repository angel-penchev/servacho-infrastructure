# One management plane per tenant pool, as docs/guide.md Phase 5 intends: a VM
# in the tenant's pool on the tenant's VLAN, cloned from the management image
# template this repository builds (nixos/images/management.nix), given its
# address and the deploy key by cloud-init, then switched to its own host
# configuration from nixos/hosts/ the way the root plane is. What each plane
# holds for its tenant, and the steps around it, are in
# docs/tenant-management-planes.md.
#
# Nothing here exists until the template does on Proxmox. Once it is restored
# under management_template_vm_id, flip tenant_management_planes_enabled to
# create the planes; until then every for_each below is empty and this file
# plans as no changes.

locals {
  tenant_management_planes_enabled = false
  management_template_vm_id        = 9003

  # VM id rule: the VLAN followed by the zero-padded last octet.
  tenant_management_planes = {
    qoax-community = {
      host    = "qoax-community-management-plane"
      vm_id   = 10011
      pool_id = proxmox_virtual_environment_pool.pool_qoax_community.id
      vlan    = 10
      address = "192.168.10.11/23"
      gateway = "192.168.10.1"
    }
    fmicodes = {
      host    = "fmicodes-management-plane"
      vm_id   = 12011
      pool_id = proxmox_virtual_environment_pool.pool_fmicodes.id
      vlan    = 12
      address = "192.168.12.11/24"
      gateway = "192.168.12.1"
    }
  }

  enabled_tenant_management_planes = (
    local.tenant_management_planes_enabled ? local.tenant_management_planes : {}
  )
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

  clone {
    vm_id = local.management_template_vm_id
    full  = true
  }

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

  # The template's disk is virtio0; naming it here only grows it.
  disk {
    interface    = "virtio0"
    datastore_id = "local-lvm"
    file_format  = "raw"
    size         = 32
    discard      = "ignore"
    iothread     = true
  }

  network_device {
    bridge   = "vmbr0"
    enabled  = true
    firewall = true
    model    = "virtio"
    vlan_id  = each.value.vlan
  }

  # Only for the first boot: the host configuration deployed below carries the
  # same address and key itself and replaces cloud-init.
  initialization {
    datastore_id = "local-lvm"
    interface    = "ide2"

    ip_config {
      ipv4 {
        address = each.value.address
        gateway = each.value.gateway
      }
    }

    dns {
      servers = ["1.1.1.1", "1.0.0.1"]
    }

    user_account {
      keys = [trimspace(file("${path.module}/../nixos/hosts/servacho-managment-plane/deploy-key.pub"))]
    }
  }

  operating_system {
    type = "l26"
  }
}

module "tenant_management_plane_system" {
  for_each = local.enabled_tenant_management_planes
  source   = "github.com/nix-community/nixos-anywhere//terraform/nix-build?ref=1.13.0"

  attribute = "${abspath("${path.module}/../nixos")}#nixosConfigurations.${each.value.host}.config.system.build.toplevel"
}

module "tenant_management_plane_deploy" {
  for_each = local.enabled_tenant_management_planes
  source   = "github.com/nix-community/nixos-anywhere//terraform/nixos-rebuild?ref=1.13.0"

  nixos_system    = module.tenant_management_plane_system[each.key].result.out
  target_host     = split("/", each.value.address)[0]
  target_user     = "root"
  ssh_private_key = data.vault_kv_secret_v2.management_plane_ssh.data["private_key"]

  depends_on = [proxmox_virtual_environment_vm.tenant_management_plane]
}
