# The root management plane, VM and NixOS: root-plane/.

# The deploy key: root on the root plane, on the organisations' planes and on
# their installer accepts it.
data "vault_kv_secret_v2" "management_plane_ssh" {
  mount = "secret"
  name  = "management-plane/ssh"
}

module "root_plane" {
  source = "./root-plane"

  nixos_flake     = local.nixos_flake
  ssh_private_key = data.vault_kv_secret_v2.management_plane_ssh.data["private_key"]
}

moved {
  from = proxmox_virtual_environment_vm.management_vm
  to   = module.root_plane.proxmox_virtual_environment_vm.this
}

moved {
  from = module.management_plane_system
  to   = module.root_plane.module.system
}

moved {
  from = module.management_plane_deploy
  to   = module.root_plane.module.deploy
}
