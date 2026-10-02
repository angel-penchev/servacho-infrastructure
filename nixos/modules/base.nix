# The baseline every servacho VM shares, whatever it goes on to run: SSH for
# the deployment tooling on the management plane, the QEMU guest agent that
# Proxmox and its backup jobs rely on, and a Nix setup that can be rebuilt in
# place without filling the disk.
{ pkgs, ... }:
{
  services.qemuGuest.enable = true;

  # Keys only. cloud-init (on a fresh clone) or the deployment tool puts the
  # management plane's key in root's authorized_keys; nothing else logs in.
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "prohibit-password";
    };
  };

  # nftables so modules can express source-restricted rules through
  # networking.firewall.extraInputRules. k3s detects the nft backend and puts
  # its own kube-proxy and flannel rules beside these.
  networking.firewall.enable = true;
  networking.nftables.enable = true;

  time.timeZone = "UTC";
  i18n.defaultLocale = "en_US.UTF-8";

  nix = {
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      auto-optimise-store = true;
    };
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 14d";
    };
  };

  environment.systemPackages = with pkgs; [
    vim
    git
    curl
    jq
    htop
  ];

  # Headless VMs: no manuals or HTML docs in the image.
  documentation.enable = false;
  documentation.nixos.enable = false;

  boot.tmp.cleanOnBoot = true;
  services.journald.extraConfig = "SystemMaxUse=1G";
}
