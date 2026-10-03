# The installer every tenant plane starts from: the minimal NixOS ISO, booted
# by a new VM whose disk is still empty. It takes a DHCP address, reports it
# through the QEMU guest agent, and lets the root plane in as root with its
# deploy key; nixos-anywhere then partitions the disk and installs the host
# (tofu/tenant_management_planes.tf). Nothing else logs in.
{ lib, modulesPath, ... }:
{
  imports = [ (modulesPath + "/installer/cd-dvd/installation-cd-minimal.nix") ];

  # A stable file name, so the uploaded ISO keeps its Proxmox volume id.
  image.baseName = lib.mkForce "servacho-installer";

  services.qemuGuest.enable = true;

  # The installer profile ships sshd without starting it, and its root has an
  # empty password for the console; over SSH only the key gets in.
  systemd.services.sshd.wantedBy = lib.mkForce [ "multi-user.target" ];
  services.openssh.settings = {
    PasswordAuthentication = false;
    KbdInteractiveAuthentication = false;
  };
  users.users.root.openssh.authorizedKeys.keyFiles = [
    ../hosts/servacho-managment-plane/deploy-key.pub
  ];

  nixpkgs.hostPlatform = "x86_64-linux";
}
