# The FMI{Codes} management plane: OpenTofu, OpenBao and the runner for the
# FMI{Codes} tenant, on its VPS network. A clone of images/management.nix,
# created and deployed by tofu/tenant_management_planes.tf.
{ ... }:
{
  imports = [ ../modules/proxmox-guest.nix ];

  networking.hostName = "fmicodes-management-plane";

  servacho.managementPlane = {
    enable = true;
    # VLAN 12 is a /24 (tofu/unifi/networks.tf); id rule: 12 + 011 = VM 12011.
    network = {
      address = "192.168.12.11";
      prefixLength = 24;
      gateway = "192.168.12.1";
    };
    # The runner joins once the tenant's infrastructure repository exists;
    # until then the plane is an OpenBao and a tofu host reached over SSH.
    runner.enable = false;
  };

  # The same key the root plane deploys with; cloud-init installs it on first
  # boot and this keeps it after the switch replaces cloud-init.
  users.users.root.openssh.authorizedKeys.keyFiles = [
    ./servacho-managment-plane/deploy-key.pub
  ];

  system.stateVersion = "26.05";
}
