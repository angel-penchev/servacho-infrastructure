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
    "VM.PowerMgmt",
    "VM.GuestAgent.Audit",
    "Datastore.AllocateSpace",
    "Datastore.Audit",
    "SDN.Use",
    "Pool.Audit"
  ]
}
