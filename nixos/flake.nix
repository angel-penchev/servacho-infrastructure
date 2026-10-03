{
  description = "servacho NixOS modules, hosts, Proxmox VM image templates and installer";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    # Partitions a VM's disk when nixos-anywhere installs a host onto it.
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      disko,
    }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      inherit (nixpkgs) lib;

      # An image template is a complete NixOS system whose build product is a
      # Proxmox VMA archive instead of something to switch a running host to.
      mkImage =
        image:
        lib.nixosSystem {
          inherit system;
          modules = [
            self.nixosModules.base
            self.nixosModules.k3s-node
            ./images/proxmox.nix
            image
          ];
        };

      # A host nixos-anywhere installs onto an empty VM disk: disko lays the
      # disk out from the host's own configuration, so no generated
      # hardware-configuration.nix is needed.
      mkInstalledHost =
        host:
        lib.nixosSystem {
          inherit system;
          modules = [
            self.nixosModules.base
            self.nixosModules.management-plane
            disko.nixosModules.disko
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
      # Reusable pieces for host configurations in this and other repositories.
      nixosModules = {
        base = ./modules/base.nix;
        k3s-node = ./modules/k3s-node.nix;
        management-plane = ./modules/management-plane.nix;
        # The hardware and disk layout of a VM installed by nixos-anywhere.
        proxmox-guest = ./modules/proxmox-guest.nix;
      };

      nixosConfigurations = {
        # Hosts: switched to in place, by tofu/nixos_management_plane.tf.
        servacho-management-plane = lib.nixosSystem {
          inherit system;
          modules = [
            self.nixosModules.base
            self.nixosModules.management-plane
            ./hosts/servacho-managment-plane/configuration.nix
            managementPlaneHardware
          ];
        };
        # Tenant planes, installed and deployed by tofu/tenant_management_planes.tf.
        qoax-community-management-plane = mkInstalledHost ./hosts/qoax-community-management-plane.nix;
        fmicodes-management-plane = mkInstalledHost ./hosts/fmicodes-management-plane.nix;

        # Image templates: cloned, never switched to.
        k3s-server = mkImage ./images/k3s-server.nix;
        k3s-agent = mkImage ./images/k3s-agent.nix;

        # The ISO an installed host boots before it has a system of its own.
        installer = lib.nixosSystem {
          inherit system;
          modules = [ ./images/installer.nix ];
        };
      };

      # nix build .#k3s-server-image -> result/vzdump-qemu-servacho-k3s-server.vma.zst
      packages.${system} = {
        k3s-server-image = self.nixosConfigurations.k3s-server.config.system.build.VMA;
        k3s-agent-image = self.nixosConfigurations.k3s-agent.config.system.build.VMA;
        # nix build .#installer-iso -> result/iso/servacho-installer.iso
        installer-iso = self.nixosConfigurations.installer.config.system.build.isoImage;
        # The CLI OpenTofu and the workflows use against the planes' OpenBao,
        # from the same nixpkgs as the planes themselves.
        openbao = pkgs.openbao;
      };

      # `nix flake check` builds the systems (a binary-cache download), not the
      # disk images, which is enough to catch a broken module.
      checks.${system} = {
        servacho-management-plane =
          self.nixosConfigurations.servacho-management-plane.config.system.build.toplevel;
        qoax-community-management-plane =
          self.nixosConfigurations.qoax-community-management-plane.config.system.build.toplevel;
        fmicodes-management-plane =
          self.nixosConfigurations.fmicodes-management-plane.config.system.build.toplevel;
        k3s-server = self.nixosConfigurations.k3s-server.config.system.build.toplevel;
        k3s-agent = self.nixosConfigurations.k3s-agent.config.system.build.toplevel;
        installer = self.nixosConfigurations.installer.config.system.build.toplevel;
      };

      formatter.${system} = pkgs.nixfmt-tree;
    };
}
