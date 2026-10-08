# The root management plane: the VM that runs this repository's OpenTofu, its
# OpenBao and its GitHub runner, and the NixOS on it, managed like the VM.
# OpenTofu builds nixosConfigurations.servacho-management-plane from ../nixos,
# and when the resulting system differs from the one last deployed, pushes it
# over SSH and switches to it.
#
# This runs on the machine it deploys to: the runner builds the closure, `nix
# copy` to itself is a no-op, and the switch happens over SSH to loopback as
# root with a key kept in OpenBao, so a change to the plane's own address
# cannot cut the session doing the switch. The runner's own unit is excluded
# from restarts in the NixOS configuration, so the job survives the switch.
# docs/management-plane-nixos.md has the one-time bootstrap.

resource "proxmox_virtual_environment_vm" "this" {
  name = "servacho-managment-plane"
  # A different node_name forces replacement -- i.e. destroys the VM that runs the apply.
  node_name     = "Servacho-Gosho"
  vm_id         = 5015
  scsi_hardware = "virtio-scsi-single"

  on_boot = true

  agent {
    enabled = true
    timeout = "15m"
    trim    = false
  }

  cpu {
    cores = 2
    type  = "x86-64-v2-AES"
  }

  disk {
    interface    = "scsi0"
    datastore_id = "local-lvm"
    file_format  = "raw"
    size         = 32
    cache        = "none"
    discard      = "ignore"
    iothread     = true
    ssd          = false
  }

  # Its plans evaluate every plane's NixOS host and the installer, up to
  # about 0.75 GB each (see the organisation module's plane.memory), and
  # between plans it balloons down to `floating`. Resize it in Proxmox first
  # and reboot it when no job runs: an apply that changed it would reboot the
  # VM it runs on.
  memory {
    dedicated = 6144
    floating  = 4096
  }

  network_device {
    bridge   = "vmbr0"
    enabled  = true
    firewall = true
    model    = "virtio"
    vlan_id  = 0
  }

  operating_system {
    type = "l26"
  }
}

module "system" {
  source = "github.com/nix-community/nixos-anywhere//terraform/nix-build?ref=1.13.0"

  # Evaluated at plan time, so a plan shows whether the system would change.
  # Flakes come from the host's nix.conf (infrastructure-reusables' base
  # module); the module's nix_options cannot carry a value with a space, and a
  # command-line experimental-features would replace the file's rather than
  # add to it.
  attribute = "${var.nixos_flake}#nixosConfigurations.servacho-management-plane.config.system.build.toplevel"
}

module "deploy" {
  source = "github.com/nix-community/nixos-anywhere//terraform/nixos-rebuild?ref=1.13.0"

  nixos_system    = module.system.result.out
  target_host     = "127.0.0.1"
  target_user     = "root"
  ssh_private_key = var.ssh_private_key
}
