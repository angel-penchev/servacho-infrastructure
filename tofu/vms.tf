# VM 5015 is the restore of 5011 (docs/management-plane-move.md); the import
# adopts it into state. Once the VM is in state the block is inert, so removing
# it after the apply is tidying, not a requirement.
import {
  id = "Servacho-Gosho/5015"
  to = proxmox_virtual_environment_vm.management_vm
}

resource "proxmox_virtual_environment_vm" "management_vm" {
  name = "servacho-managment-plane"
  # A different node_name forces replacement -- i.e. destroys the VM that runs the apply.
  node_name     = "Servacho-Gosho"
  vm_id         = 5015
  scsi_hardware = "virtio-scsi-single"

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
}
