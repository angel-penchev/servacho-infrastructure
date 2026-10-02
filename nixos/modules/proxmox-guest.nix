# The hardware of a VM cloned from one of this repository's Proxmox templates
# (images/proxmox.nix): one virtio disk with the root filesystem labelled by
# the image build, legacy GRUB on it, and the QEMU guest profile. A host that
# imports this needs no generated hardware-configuration.nix.
{ lib, modulesPath, ... }:
{
  imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];

  boot.loader.grub = {
    enable = true;
    device = "/dev/vda";
  };
  boot.initrd.availableKernelModules = [
    "uas"
    "virtio_blk"
    "virtio_pci"
  ];
  # OpenTofu sizes the clone's disk; the partition and filesystem follow on boot.
  boot.growPartition = true;

  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
    autoResize = true;
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
