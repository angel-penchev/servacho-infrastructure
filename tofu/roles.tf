resource "proxmox_virtual_environment_role" "tofu_provisioner" {
  role_id = "TofuProvisioner"
  privileges = [
    "VM.Allocate",
    "VM.Audit",
    "VM.Clone",
    "VM.Config.CPU",
    "VM.Config.Memory",
    "VM.Config.Network",
    "VM.Config.HWType",
    "VM.Config.Disk",
    "VM.Config.Options",
    "VM.Config.Cloudinit",
    "VM.Config.CDROM",
    "VM.PowerMgmt",
    "VM.GuestAgent.Audit",
    "Datastore.AllocateSpace",
    "Datastore.Audit",
    "SDN.Use",
    "Pool.Audit"
  ]
}

# What an organisation's OpenTofu user needs outside its pool to create a VM,
# each granted on one path only (organisation/main.tf): disk space on the VM
# storage, its own ISO storage, and its VLAN on the bridge.

resource "proxmox_virtual_environment_role" "tofu_disks" {
  role_id = "TofuDisks"
  privileges = [
    "Datastore.AllocateSpace",
    "Datastore.Audit",
  ]
}

# Upload and delete in that storage. Changing a storage's definition needs
# Datastore.Allocate on /storage itself, which no organisation has.
resource "proxmox_virtual_environment_role" "tofu_isos" {
  role_id = "TofuIsos"
  privileges = [
    "Datastore.Allocate",
    "Datastore.AllocateTemplate",
    "Datastore.Audit",
  ]
}

resource "proxmox_virtual_environment_role" "tofu_network" {
  role_id = "TofuNetwork"
  privileges = [
    "SDN.Use",
  ]
}
