# The root management plane is being moved from VM 5011 to VM 5015
# (docs/management-plane-move.md). OpenTofu forgets 5011 here and adopts 5015
# in the next step; it never destroys either, since the VM runs this apply.
removed {
  from = proxmox_virtual_environment_vm.management_vm

  lifecycle {
    destroy = false
  }
}
