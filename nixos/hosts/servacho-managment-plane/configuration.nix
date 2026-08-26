{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/sda";
  boot.loader.grub.useOSProber = true;

  networking.hostName = "servacho-management-plane";
  networking.networkmanager.enable = true;
  networking.interfaces.eth0.ipv4.addresses = [{
    address = "192.168.5.11";
    prefixLength = 24;
  }];
  networking.defaultGateway = "192.168.5.1";
  networking.nameservers = [ "1.1.1.1" "1.0.0.1" ];

  time.timeZone = "UTC";

  i18n.defaultLocale = "en_US.UTF-8";

  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  users.users."servacho-managment-plane" = {
    isNormalUser = true;
    description = "servacho-managment-plane";
    extraGroups = [ "networkmanager" "wheel" ];
    packages = with pkgs; [];
  };

  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [
    opentofu
    git
    colmena
    vim
    neovim
    openbao
  ];

  services.openbao = {
    enable = true;
    settings = {
      ui = true;
      api_addr = "http://127.0.0.1:8200";
      listener.tcp = {
        address = "127.0.0.1:8200";
        tls_disable = 1;
      };
      storage.file = {
        path = "/var/lib/openbao";
      };
    };
  };

  environment.variables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
  };

  # OpenBao is only reachable by processes on this management VM. The GitHub
  # Actions runner uses a dedicated token rather than an interactive SSO flow.
  services.openbao = {
    enable = true;
    settings = {
      ui = true;
      api_addr = "http://127.0.0.1:8200";
      cluster_addr = "http://127.0.0.1:8201";

      listener.tcp = {
        address = "127.0.0.1:8200";
        tls_disable = 1;
      };

      storage.raft = {
        path = "/var/lib/openbao";
        node_id = "servacho-management-plane";
      };
    };
  };

  services.openssh = {
    enable = true;
    settings.PermitRootLogin = "prohibit-password";
  };

  services.github-runners = {
    management-runner = {
      enable = true;
      url = "https://github.com/angel-penchev/servacho-infrastructure";
      tokenFile = "/var/lib/github-runner/.token";
      extraPackages = with pkgs; [ opentofu git colmena ];
      extraLabels = [ "servacho-management-plane" "self-hosted" ];

      # The runner service uses ProtectSystem=strict. StateDirectory makes
      # this persistent directory writable to its dynamically allocated user.
      serviceOverrides = {
        StateDirectory = [ "github-runner/management-runner" "opentofu" ];
        StateDirectoryMode = "0700";
      };
      
      # Bypass the local channel and fetch the latest version from unstable
      package = (import (fetchTarball "https://github.com/NixOS/nixpkgs/archive/nixos-unstable.tar.gz") { 
        config.allowUnfree = true; 
      }).github-runner;
    };
  };

  # Keep parent directory traversable for the runner service process.
  systemd.tmpfiles.rules = [
    "d /var/lib/github-runner 0755 root root -"
  ];

  services.qemuGuest.enable = true;

  system.stateVersion = "25.05";
}