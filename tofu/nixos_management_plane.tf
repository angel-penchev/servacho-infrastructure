# The management plane's operating system, managed like its VM: OpenTofu
# builds nixosConfigurations.servacho-management-plane from ../nixos, and when
# the resulting system differs from the one last deployed, pushes it over SSH
# and switches to it. The same shape as tweag's deploy_nixos, from the module
# set nix-community maintains today.
#
# This runs on the machine it deploys to: the runner builds the closure, `nix
# copy` to itself is a no-op, and the switch happens over SSH to 192.168.5.11
# as root with a key kept in OpenBao. The runner's own unit is excluded from
# restarts in the NixOS configuration, so the job survives the switch.
# docs/management-plane-nixos.md has the one-time bootstrap.

data "vault_kv_secret_v2" "management_plane_ssh" {
  mount = "secret"
  name  = "management-plane/ssh"
}

module "management_plane_system" {
  source = "github.com/nix-community/nixos-anywhere//terraform/nix-build?ref=1.13.0"

  # Evaluated at plan time, so a plan shows whether the system would change.
  attribute = "${abspath("${path.module}/../nixos")}#nixosConfigurations.servacho-management-plane.config.system.build.toplevel"

  # Passed on the command line so the first deployment works from a host whose
  # nix.conf does not enable flakes yet.
  nix_options = {
    experimental-features = "nix-command flakes"
  }
}

module "management_plane_deploy" {
  source = "github.com/nix-community/nixos-anywhere//terraform/nixos-rebuild?ref=1.13.0"

  nixos_system = module.management_plane_system.result.out
  # The static address from nixos/hosts/servacho-managment-plane/configuration.nix.
  target_host     = "192.168.5.11"
  target_user     = "root"
  ssh_private_key = data.vault_kv_secret_v2.management_plane_ssh.data["private_key"]

  depends_on = [proxmox_virtual_environment_vm.management_vm]
}
