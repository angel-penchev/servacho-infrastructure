# A management plane: the VM that holds one tenant's OpenTofu state, its
# OpenBao and, once the tenant has an infrastructure repository, the GitHub
# Actions runner that applies it. The root plane and every tenant plane are
# this module with a different address, OpenBao node and repository
# (docs/tenant-management-planes.md).
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.servacho.managementPlane;
  inherit (lib)
    mkOption
    mkEnableOption
    mkIf
    types
    ;
in
{
  options.servacho.managementPlane = {
    enable = mkEnableOption "a servacho management plane";

    openbao.nodeId = mkOption {
      type = types.str;
      default = config.networking.hostName;
      defaultText = lib.literalExpression "config.networking.hostName";
      description = "Raft node id of this plane's single-node OpenBao.";
    };

    network = mkOption {
      type = types.nullOr (
        types.submodule {
          options = {
            address = mkOption {
              type = types.str;
              example = "192.168.10.11";
            };
            prefixLength = mkOption {
              type = types.ints.between 0 32;
              example = 23;
            };
            gateway = mkOption {
              type = types.str;
              example = "192.168.10.1";
            };
            nameservers = mkOption {
              type = types.listOf types.str;
              default = [
                "1.1.1.1"
                "1.0.0.1"
              ];
            };
          };
        }
      );
      default = null;
      description = ''
        A static address for the plane's one interface, applied through
        systemd-networkd to whichever ethernet device the VM has. null leaves
        networking to the host configuration, as on the hand-installed root
        plane.
      '';
    };

    runner = {
      enable = mkEnableOption "the GitHub Actions runner that applies this plane's repository";

      name = mkOption {
        type = types.str;
        default = "management-runner";
        description = "Runner name; the systemd unit is github-runner-<name>.";
      };

      url = mkOption {
        type = types.str;
        example = "https://github.com/angel-penchev/servacho-infrastructure";
        description = "The repository the runner registers with.";
      };

      labels = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Labels the repository's workflows select the runner by.";
      };

      tokenFile = mkOption {
        type = types.str;
        default = "/var/lib/github-runner/.token";
        description = "Registration token, placed by hand once per plane.";
      };
    };
  };

  config = mkIf cfg.enable {
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

    # OpenBao is only reachable by processes on the plane itself. Workloads
    # that need a tenant's secrets get a listener on the tenant VLAN, with TLS,
    # when that tenant's first consumer arrives; nothing opens it before.
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
          node_id = cfg.openbao.nodeId;
        };
      };
    };

    systemd.network = mkIf (cfg.network != null) {
      enable = true;
      networks."10-lan" = {
        matchConfig.Type = "ether";
        address = [ "${cfg.network.address}/${toString cfg.network.prefixLength}" ];
        gateway = [ cfg.network.gateway ];
        dns = cfg.network.nameservers;
      };
    };
    networking.useDHCP = mkIf (cfg.network != null) false;

    services.github-runners = mkIf cfg.runner.enable {
      ${cfg.runner.name} = {
        enable = true;
        inherit (cfg.runner) url tokenFile;
        extraPackages = with pkgs; [
          opentofu
          git
          colmena
          # The plane deploys its own and its tenants' NixOS from inside a job
          # (tofu/nixos_management_plane.tf): nix-build.sh needs jq, nix copy
          # and the switch need ssh.
          jq
          openssh
        ];
        extraLabels = cfg.runner.labels;

        # The runner service uses ProtectSystem=strict. StateDirectory makes
        # this persistent directory writable to its dynamically allocated user.
        serviceOverrides = {
          StateDirectory = [
            "github-runner/${cfg.runner.name}"
            "opentofu"
          ];
          StateDirectoryMode = "0700";
        };
      };
    };

    # The runner deploys this very configuration from inside a job. Restarting
    # its unit mid-switch would kill that job and leave OpenTofu's state locked,
    # so a new runner version waits for the next reboot or a manual restart.
    systemd.services."github-runner-${cfg.runner.name}" = mkIf cfg.runner.enable {
      restartIfChanged = false;
    };

    # Keep parent directory traversable for the runner service process.
    systemd.tmpfiles.rules = mkIf cfg.runner.enable [
      "d /var/lib/github-runner 0755 root root -"
    ];
  };
}
