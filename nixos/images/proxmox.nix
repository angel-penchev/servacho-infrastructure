# What turns a NixOS system into a Proxmox VM template rather than a host: the
# VMA archive build, the QEMU hardware that archive declares, and cloud-init so
# a clone takes its name, address and SSH keys from Proxmox on first boot.
#
# Hosts deployed onto a clone later do not import this file; they import the
# modules only. The template is what a node is before it knows its cluster.
{ lib, modulesPath, ... }:
{
  imports = [ "${modulesPath}/virtualisation/proxmox-image.nix" ];

  proxmox = {
    qemuConf = {
      # The same controller and CPU type as the VMs in tofu/vms.tf, so a clone
      # needs no hardware changes to boot; OpenTofu resizes cores, memory and
      # disk per node.
      scsihw = "virtio-scsi-single";
      bios = "seabios";
      cores = 4;
      memory = 8192;
      # Room for k3s to unpack its images on a first boot that happens before
      # the disk is grown to the node's size.
      additionalSpace = "2048M";
    };
    qemuExtraConf = {
      cpu = "x86-64-v2-AES";
      # An image that is not a k3s node sets its own.
      tags = lib.mkDefault "nixos;k3s";
    };
    cloudInit = {
      enable = true;
      defaultStorage = "local-lvm";
      device = "ide2";
    };
  };

  system.stateVersion = "26.05";
}
