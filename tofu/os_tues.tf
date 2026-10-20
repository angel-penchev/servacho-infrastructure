# os-tues: the machine TUES' operating systems class works on, one account per
# student, reached from anywhere as <student>@os-tues.qo.ax (docs/os-tues.md).
# A NixOS VM on Public Servers, installed and deployed like an organisation's
# plane by infrastructure-reusables' nixos-vm; its host is
# ../nixos/hosts/os-tues/. The port forward is in unifi/port_forwards.tf, the
# DNS record in qoax-infrastructure. The students' accounts are not
# infrastructure: .github/workflows/os-tues-students.yaml makes them from a
# sigma export.

# VM id rule as for the planes: VLAN 4 followed by the zero-padded last octet.
# Sized for a class of about 25 logged in at once, each held to 2 GiB and two
# cores by the host's per-login limits; /home is a disk of its own.
module "os_tues" {
  source = "github.com/angel-penchev/infrastructure-reusables//tofu/modules/nixos-vm?ref=v0.8.0"

  name             = "os-tues"
  node_name        = "Servacho-Gosho"
  vm_id            = 4031
  tags             = ["nixos", "os-tues"]
  vlan_id          = 4
  cores            = 4
  memory           = 12288
  memory_floating  = 4096
  disk_size        = 64
  data_disks       = [{ size = 64 }]
  installer_iso_id = local.plane_tools.installer_iso_id
  flake            = local.nixos_flake
  host             = "os-tues"
  address          = "192.168.4.31"
  ssh_private_key  = data.vault_kv_secret_v2.management_plane_ssh.data["private_key"]
}
