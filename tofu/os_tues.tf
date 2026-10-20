# os-tues: the machine TUES' operating systems class works on, one account per
# student, reached from anywhere as <student>@os-tues.qo.ax (docs/os-tues.md).
# A NixOS VM on Public Servers, installed and deployed like an organisation's
# plane by infrastructure-reusables' nixos-vm; its host is
# ../nixos/hosts/os-tues.nix. The port forward is in unifi/port_forwards.tf,
# the DNS record in qoax-infrastructure.

# The students: user name to initial password hash, put in the root OpenBao by
# hand (docs/os-tues.md). Not in this public repository, and never in a plan:
# the data is sensitive, so the provisioner below logs nothing either.
locals {
  # Off until secret/os-tues/students is in the root OpenBao; until then the
  # roster is copied to the host by hand (docs/os-tues.md).
  os_tues_roster = false
}

data "vault_kv_secret_v2" "os_tues_students" {
  count = local.os_tues_roster ? 1 : 0

  mount = "secret"
  name  = "os-tues/students"
}

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

# Hands the host the roster, whose os-tues-students service creates the
# accounts of new students and locks those taken off it. Again for every
# change to the roster and every new installation.
resource "terraform_data" "os_tues_students" {
  count = local.os_tues_roster ? 1 : 0

  triggers_replace = [
    module.os_tues.installation_id,
    sha256(jsonencode(data.vault_kv_secret_v2.os_tues_students[0].data)),
  ]

  provisioner "local-exec" {
    command = abspath("${path.module}/../scripts/os-tues-students.sh")
    environment = {
      TARGET_HOST     = module.os_tues.address
      SSH_PRIVATE_KEY = data.vault_kv_secret_v2.management_plane_ssh.data["private_key"]
      ROSTER          = jsonencode(data.vault_kv_secret_v2.os_tues_students[0].data)
    }
  }

  depends_on = [module.os_tues]
}
