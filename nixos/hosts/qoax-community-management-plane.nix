# The Qoax Community management plane: OpenTofu, OpenBao and the runner for
# the qoax tenant, on the qoax VPS network. Installed from
# images/installer.nix and deployed by tofu/tenant_management_planes.tf.
{ ... }:
{
  imports = [ ../modules/proxmox-guest.nix ];

  networking.hostName = "qoax-community-management-plane";

  servacho.managementPlane = {
    enable = true;
    # A management plane takes .15 of its VLAN. VLAN 10 is a /23
    # (tofu/unifi/networks.tf); id rule: 10 + 015 = VM 10015.
    network = {
      address = "192.168.10.15";
      prefixLength = 23;
      gateway = "192.168.10.1";
    };
    # The runner joins once the tenant's infrastructure repository exists;
    # until then the plane is an OpenBao and a tofu host reached over SSH.
    runner.enable = false;
  };

  # The same key the root plane deploys with, as on the installer it starts from.
  users.users.root.openssh.authorizedKeys.keyFiles = [
    ./servacho-managment-plane/deploy-key.pub
  ];

  system.stateVersion = "26.05";
}
