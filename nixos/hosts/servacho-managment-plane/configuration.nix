# The root management plane: the VM that runs OpenTofu, OpenBao and the GitHub
# Actions runner for this repository. What it shares with the tenant planes is
# modules/management-plane.nix; this file is what is particular to it. Built as
# nixosConfigurations.servacho-management-plane in ../../flake.nix and deployed
# by tofu/nixos_management_plane.tf; see docs/management-plane-nixos.md.
{ ... }:

{
  # hardware-configuration.nix is the file nixos-generate-config wrote on the
  # VM; the flake imports it and refuses to evaluate without it.

  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/sda";
  boot.loader.grub.useOSProber = true;

  # Installed by hand before the module existed, so networking stays as the
  # installer left it rather than moving to the module's networkd layout.
  networking.hostName = "servacho-management-plane";
  networking.networkmanager.enable = true;
  networking.interfaces.eth0.ipv4.addresses = [
    {
      address = "192.168.5.11";
      prefixLength = 24;
    }
  ];
  networking.defaultGateway = "192.168.5.1";
  networking.nameservers = [
    "1.1.1.1"
    "1.0.0.1"
  ];

  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  users.users."servacho-managment-plane" = {
    isNormalUser = true;
    description = "servacho-managment-plane";
    extraGroups = [
      "networkmanager"
      "wheel"
    ];
  };

  # The key OpenTofu deploys this configuration with (docs/management-plane-nixos.md).
  # Keys added by hand to /root/.ssh/authorized_keys keep working beside it.
  users.users.root.openssh.authorizedKeys.keyFiles = [ ./deploy-key.pub ];

  servacho.managementPlane = {
    enable = true;
    runner = {
      enable = true;
      name = "management-runner";
      url = "https://github.com/angel-penchev/servacho-infrastructure";
      labels = [
        "servacho-management-plane"
        "self-hosted"
      ];
    };
  };

  system.stateVersion = "25.05";
}
