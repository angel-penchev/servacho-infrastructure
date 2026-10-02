# The management plane's operating system, managed like its VM: OpenTofu
# builds nixosConfigurations.servacho-management-plane from ../nixos, and when
# the resulting system differs from the one last deployed, pushes it over SSH
# and switches to it. The same shape as tweag's deploy_nixos, from the module
# set nix-community maintains today.
#
# This runs on the machine it deploys to: the runner builds the closure, `nix
# copy` to itself is a no-op, and the switch happens over SSH to loopback as
# root with a key kept in OpenBao, so a change to the plane's own address
# cannot cut the session doing the switch. The runner's own unit is excluded
# from restarts in the NixOS configuration, so the job survives the switch.
# docs/management-plane-nixos.md has the one-time bootstrap.

data "vault_kv_secret_v2" "management_plane_ssh" {
  mount = "secret"
  name  = "management-plane/ssh"
}

module "management_plane_system" {
  source = "github.com/nix-community/nixos-anywhere//terraform/nix-build?ref=1.13.0"

  # Evaluated at plan time, so a plan shows whether the system would change.
  # Flakes come from the host's nix.conf (modules/base.nix); the module's
  # nix_options cannot carry a value with a space, and a command-line
  # experimental-features would replace the file's rather than add to it.
  attribute = "${abspath("${path.module}/../nixos")}#nixosConfigurations.servacho-management-plane.config.system.build.toplevel"
}

module "management_plane_deploy" {
  source = "github.com/nix-community/nixos-anywhere//terraform/nixos-rebuild?ref=1.13.0"

  nixos_system    = module.management_plane_system.result.out
  target_host     = "127.0.0.1"
  target_user     = "root"
  ssh_private_key = data.vault_kv_secret_v2.management_plane_ssh.data["private_key"]
}
