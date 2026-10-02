{
  description = "servacho NixOS modules, hosts and Proxmox VM image templates";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

  outputs =
    { self, nixpkgs }:
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
            self.nixosModules.management-plane
            ./images/proxmox.nix
            image
          ];
        };

      # A host cloned from a template: the clone's hardware is known, so no
      # generated hardware-configuration.nix is needed.
      mkClonedHost =
        host:
        lib.nixosSystem {
          inherit system;
          modules = [
            self.nixosModules.base
            self.nixosModules.management-plane
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
        # The hardware of a VM cloned from one of the images below.
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
        # Tenant planes, deployed by tofu/tenant_management_planes.tf.
        qoax-community-management-plane = mkClonedHost ./hosts/qoax-community-management-plane.nix;
        fmicodes-management-plane = mkClonedHost ./hosts/fmicodes-management-plane.nix;

        # Image templates: cloned, never switched to.
        k3s-server = mkImage ./images/k3s-server.nix;
        k3s-agent = mkImage ./images/k3s-agent.nix;
        management = mkImage ./images/management.nix;
      };

      # nix build .#k3s-server-image -> result/vzdump-qemu-servacho-k3s-server.vma.zst
      packages.${system} = {
        k3s-server-image = self.nixosConfigurations.k3s-server.config.system.build.VMA;
        k3s-agent-image = self.nixosConfigurations.k3s-agent.config.system.build.VMA;
        management-image = self.nixosConfigurations.management.config.system.build.VMA;
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
        management = self.nixosConfigurations.management.config.system.build.toplevel;
      };

      formatter.${system} = pkgs.nixfmt-tree;
    };
}
