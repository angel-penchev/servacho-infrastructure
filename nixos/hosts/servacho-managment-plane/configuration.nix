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
  ];

  environment.variables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
  };

  services.openssh = {
    enable = true;
    settings.PermitRootLogin = "prohibit-password";
  };

  system.stateVersion = "25.05";
}