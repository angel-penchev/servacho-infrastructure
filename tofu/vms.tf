# Commented out because the import block is a one-time operation.
# Once the VM is successfully imported into the OpenTofu state file, 
# this block is no longer needed and can be safely disabled.
# import {
#   id = "Servacho-Alice/5011"
#   to = proxmox_virtual_environment_vm.management_vm
# }

resource "proxmox_virtual_environment_vm" "management_vm" {
  name          = "servacho-managment-plane"
  node_name     = "Servacho-Alice"
  vm_id         = 5011
  scsi_hardware = "virtio-scsi-single"

  # Reflecting the manual configuration
  on_boot = true

  agent {
    enabled = true
    timeout = "15m"
    trim    = false
  }

  cpu {
    cores = 2
    type  = "x86-64-v2-AES"
  }

  disk {
    interface    = "scsi0"
    datastore_id = "local-lvm"
    file_format  = "raw"
    size         = 32
    cache        = "none"
    discard      = "ignore"
    iothread     = true
    ssd          = false
  }

  memory {
    dedicated = 4096
  }

  network_device {
    bridge   = "vmbr0"
    enabled  = true
    firewall = true
    model    = "virtio"
    vlan_id  = 0
  }

  operating_system {
    type = "l26"
  }

  # Commented out because we now WANT OpenTofu to actively manage this VM. 
  # Keeping 'ignore_changes = all' would prevent updating things like CPU or RAM
  # in the future.
  lifecycle {
    # Bootstrap safety: import state first without mutating the VM that is
    # currently running OpenTofu. Remove this once applying from another host
    # and when ready to reconcile config changes intentionally.
    # ignore_changes = all
  }
}
