resource "proxmox_virtual_environment_vm" "management_vm" {
  name = "servacho-managment-plane"
  # A different node_name forces replacement -- i.e. destroys the VM that runs the apply.
  node_name     = "Servacho-Gosho"
  vm_id         = 5011
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
