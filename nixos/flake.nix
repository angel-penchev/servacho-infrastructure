{
  description = "servacho's management planes: the root plane and every organisation's plane";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    # The NixOS modules and installer shared with the organisations'
    # infrastructure repositories.
    reusables = {
      url = "github:angel-penchev/infrastructure-reusables/v0.1.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      reusables,
    }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      inherit (nixpkgs) lib;

      # An organisation's plane, installed onto an empty VM disk by
      # tofu/tenant_management_planes.tf: the disk layout comes with
      # proxmox-guest, so no generated hardware-configuration.nix is needed.
      mkInstalledPlane =
        host:
        lib.nixosSystem {
          inherit system;
          modules = [
            reusables.nixosModules.base
            reusables.nixosModules.management-plane
            reusables.nixosModules.proxmox-guest
            host
          ];
        };

      # Two files of the management plane are not in git until someone puts
      # them there (docs/management-plane-nixos.md): the hardware description
      # nixos-generate-config wrote on the VM, and the public half of the key
      # OpenTofu deploys with. A flake only sees tracked files, so a missing
      # one is reported by name instead of as a bare "path does not exist".
      managementPlaneDir = ./hosts/servacho-managment-plane;
      managementPlaneFiles = [
        "hardware-configuration.nix"
        "deploy-key.pub"
      ];
      managementPlaneMissing = builtins.filter (
        f: !builtins.pathExists (managementPlaneDir + "/${f}")
      ) managementPlaneFiles;
      managementPlaneHardware =
        if managementPlaneMissing == [ ] then
          managementPlaneDir + "/hardware-configuration.nix"
        else
          {
            assertions = [
              {
                assertion = false;
                message = ''
                  servacho-management-plane: missing ${lib.concatStringsSep " and " managementPlaneMissing}
                  in nixos/hosts/servacho-managment-plane/. Copy them in and commit them;
                  docs/management-plane-nixos.md says where they come from.
                '';
              }
            ];
          };
    in
    {
      nixosConfigurations = {
        # The root plane, switched to in place by tofu/nixos_management_plane.tf.
        servacho-management-plane = lib.nixosSystem {
          inherit system;
          modules = [
            reusables.nixosModules.base
            reusables.nixosModules.management-plane
            ./hosts/servacho-managment-plane/configuration.nix
            managementPlaneHardware
          ];
        };

        # The organisations' planes, installed and deployed by
        # tofu/tenant_management_planes.tf.
        qoax-community-management-plane = mkInstalledPlane ./hosts/qoax-community-management-plane.nix;
        fmicodes-management-plane = mkInstalledPlane ./hosts/fmicodes-management-plane.nix;

        # The ISO an organisation's plane boots before it has a system of its own.
        installer = lib.nixosSystem {
          inherit system;
          modules = [
            reusables.nixosModules.installer
            ./images/installer.nix
          ];
        };
      };

      packages.${system} = {
        # nix build .#installer-iso -> result/iso/servacho-installer.iso
        installer-iso = self.nixosConfigurations.installer.config.system.build.isoImage;
        # The CLI OpenTofu and the workflows use against the planes' OpenBao,
        # from the same nixpkgs as the planes themselves.
        openbao = pkgs.openbao;
      };

      # `nix flake check` builds the systems (a binary-cache download), not the
      # ISO, which is enough to catch a broken host.
      checks.${system} = {
        servacho-management-plane =
          self.nixosConfigurations.servacho-management-plane.config.system.build.toplevel;
        qoax-community-management-plane =
          self.nixosConfigurations.qoax-community-management-plane.config.system.build.toplevel;
        fmicodes-management-plane =
          self.nixosConfigurations.fmicodes-management-plane.config.system.build.toplevel;
        installer = self.nixosConfigurations.installer.config.system.build.toplevel;
      };

      formatter.${system} = pkgs.nixfmt-tree;
    };
}
