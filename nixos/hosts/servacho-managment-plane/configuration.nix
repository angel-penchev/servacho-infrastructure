# The management plane: the VM that runs OpenTofu, OpenBao and the GitHub
# Actions runner for this repository. Built as nixosConfigurations
# .servacho-management-plane in ../../flake.nix on top of modules/base.nix, and
# deployed by tofu/nixos_management_plane.tf; see docs/management-plane-nixos.md.
{ config, pkgs, ... }:

{
  # hardware-configuration.nix is the file nixos-generate-config wrote on the
  # VM; the flake imports it and refuses to evaluate without it.

  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/sda";
  boot.loader.grub.useOSProber = true;

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
    packages = with pkgs; [ ];
  };

  # The key OpenTofu deploys this configuration with (docs/management-plane-nixos.md).
  # Keys added by hand to /root/.ssh/authorized_keys keep working beside it.
  users.users.root.openssh.authorizedKeys.keyFiles = [ ./deploy-key.pub ];

  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [
    opentofu
    git
    colmena
    vim
    neovim
    openbao
  ];

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
        type = "tcp";
        address = "127.0.0.1:8200";
        tls_disable = 1;
      };

      storage.raft = {
        path = "/var/lib/openbao";
        node_id = "servacho-management-plane";
      };
    };
  };

  services.github-runners = {
    management-runner = {
      enable = true;
      url = "https://github.com/angel-penchev/servacho-infrastructure";
      tokenFile = "/var/lib/github-runner/.token";
      extraPackages = with pkgs; [
        opentofu
        git
        colmena
        # tofu/nixos_management_plane.tf builds this system and pushes it over
        # SSH from inside a job: nix-build.sh needs jq, nix copy and the switch
        # need ssh.
        jq
        openssh
      ];
      extraLabels = [
        "servacho-management-plane"
        "self-hosted"
      ];

      # The runner service uses ProtectSystem=strict. StateDirectory makes
      # this persistent directory writable to its dynamically allocated user.
      serviceOverrides = {
        StateDirectory = [
          "github-runner/management-runner"
          "opentofu"
        ];
        StateDirectoryMode = "0700";
      };
    };
  };

  # The runner deploys this very configuration from inside a job. Restarting
  # its unit mid-switch would kill that job and leave OpenTofu's state locked,
  # so a new runner version waits for the next reboot or a manual restart.
  systemd.services.github-runner-management-runner.restartIfChanged = false;

  # Keep parent directory traversable for the runner service process.
  systemd.tmpfiles.rules = [
    "d /var/lib/github-runner 0755 root root -"
  ];

  system.stateVersion = "25.05";
}
