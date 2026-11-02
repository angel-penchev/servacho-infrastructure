# The ingress VM and the NixOS on it: ingress/. Its HAProxy sends the
# internet's 80 and 443 to each tenant's servers by name, without ending TLS
# (docs/ingress.md). The tenants are ../nixos/hosts/ingress/tenants.json,
# which unifi/ingress.tf reads too, to open the gateway to each tenant's
# servers.

module "ingress" {
  source = "./ingress"

  installer_iso_id = local.plane_tools.installer_iso_id
  nixos_flake      = local.nixos_flake
  ssh_private_key  = data.vault_kv_secret_v2.management_plane_ssh.data["private_key"]
}
