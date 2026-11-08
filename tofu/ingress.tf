# ingress: the VM whose HAProxy routes the internet's 80 and 443 to each
# tenant by name (docs/ingress.md). Its host is ../nixos/hosts/ingress/, its
# policies unifi/ingress.tf. It belongs to no organisation, so to no pool.

# VM id rule as for the planes: VLAN 4 followed by the zero-padded last octet.
# HAProxy passes connections on unopened, so one core and 1 GiB carry its
# connection limits with room to spare (docs/ingress.md).
module "ingress" {
  source = "github.com/angel-penchev/infrastructure-reusables//tofu/modules/nixos-vm?ref=v0.9.1"

  name             = "ingress"
  node_name        = "Servacho-Gosho"
  vm_id            = 4016
  tags             = ["nixos", "ingress"]
  vlan_id          = 4
  cores            = 1
  memory           = 1024
  memory_floating  = 512
  disk_size        = 16
  installer_iso_id = local.plane_tools.installer_iso_id
  flake            = local.nixos_flake
  host             = "ingress"
  address          = jsondecode(file("${local.nixos_flake}/hosts/ingress/vm.json")).address
  ssh_private_key  = data.vault_kv_secret_v2.management_plane_ssh.data["private_key"]
}
