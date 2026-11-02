# The ingress VM: HAProxy on Public Servers, in the Dmz zone, sending the
# internet's 80 and 443 to each tenant's servers by name (docs/ingress.md).
# Installed and deployed like os-tues by infrastructure-reusables' nixos-vm;
# its host is ../../nixos/hosts/ingress/, and adding a tenant to that host's
# tenants.json redeploys it in place. It belongs to no organisation, so it
# is in no pool.

# VM id rule as for the planes: VLAN 4 followed by the zero-padded last
# octet. HAProxy passes connections on without opening them, so one core and
# 1 GiB carry its 4,096 connections (about 135 MB) with room to spare; when
# the host runs short, the VM gives memory back down to 512 MiB.
module "vm" {
  source = "github.com/angel-penchev/infrastructure-reusables//tofu/modules/nixos-vm?ref=v0.8.0"

  name             = "ingress"
  node_name        = "Servacho-Gosho"
  vm_id            = 4016
  tags             = ["nixos", "ingress"]
  vlan_id          = 4
  cores            = 1
  memory           = 1024
  memory_floating  = 512
  disk_size        = 16
  installer_iso_id = var.installer_iso_id
  flake            = var.nixos_flake
  host             = "ingress"
  address          = "192.168.4.16"
  ssh_private_key  = var.ssh_private_key
}
