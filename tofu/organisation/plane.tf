# The organisation's management plane: a VM in its pool on its VLAN, holding
# its OpenTofu state, its OpenBao and, later, the runner for its infrastructure
# repository (docs/tenant-management-planes.md). From an empty VM to an
# unsealed OpenBao with nothing run by hand:
#
#   1. infrastructure-reusables' nixos-vm boots the installer, nixos-anywhere
#      installs the plane's host from ../nixos, and the plane comes up on its
#      static .15 address, deployed like the root plane from then on;
#   2. scripts/tenant-plane-openbao.sh initialises its OpenBao, keeps the keys
#      in the root OpenBao and seeds it with this organisation's Proxmox token.

module "plane" {
  count  = var.plane == null ? 0 : 1
  source = "github.com/angel-penchev/infrastructure-reusables//tofu/modules/nixos-vm?ref=v0.1.0"

  name             = var.plane.host
  node_name        = var.node_name
  vm_id            = var.plane.vm_id
  pool_id          = proxmox_virtual_environment_pool.this.id
  tags             = ["nixos", "management-plane", var.id]
  vlan_id          = var.plane.vlan
  installer_iso_id = var.installer_iso_id
  flake            = var.nixos_flake
  host             = var.plane.host
  address          = var.plane.address
  ssh_private_key  = var.ssh_private_key
}

# Once per installation. The root OpenBao's address and token come from the
# workflow's environment, as for the vault provider.
resource "terraform_data" "openbao" {
  count = var.plane == null ? 0 : 1

  triggers_replace = [module.plane[0].installation_id]

  provisioner "local-exec" {
    command = "${abspath("${path.module}/../../scripts/tenant-plane-openbao.sh")} bootstrap"
    environment = {
      BAO                  = var.openbao_cli
      TENANT               = var.id
      TARGET_HOST          = var.plane.address
      PROXMOX_TOKEN_SECRET = vault_kv_secret_v2.proxmox_token.name
    }
  }

  depends_on = [module.plane]
}
