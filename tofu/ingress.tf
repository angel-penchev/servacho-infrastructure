# ingress: the VM the gateway forwards the internet's 80 and 443 to. Its
# HAProxy sends each connection to its tenant's servers by name, without
# ending TLS (docs/ingress.md). A NixOS VM on Public Servers, in the Dmz zone,
# installed and deployed like os-tues by infrastructure-reusables' nixos-vm;
# its host is ../nixos/hosts/ingress/. The tenants are that host's
# tenants.json: adding one redeploys the VM in place, and unifi/ingress.tf
# reads the same file to open the gateway to each tenant's servers. It
# belongs to no organisation, so it is in no pool.

# VM id rule as for the planes: VLAN 4 followed by the zero-padded last octet.
# HAProxy passes connections on without opening them, so one core and 1 GiB
# carry its 4,096 connections (about 135 MB) with room to spare; when the
# host runs short, the VM gives memory back down to 512 MiB.
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
  address          = "192.168.4.16"
  ssh_private_key  = data.vault_kv_secret_v2.management_plane_ssh.data["private_key"]
}
