# The Qoax Community management plane: OpenTofu, OpenBao and the runner for
# the qoax tenant, on the qoax VPS network. Installed from
# images/installer.nix and deployed by tofu/organisation/plane.tf; the
# VM's hardware and disk layout come from infrastructure-reusables.
{ ... }:
{
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
    # Applies qoax-community/qoax-infrastructure. Its registration token is
    # placed by the root plane after the deploy (tofu/organisation/plane.tf).
    runner = {
      enable = true;
      url = "https://github.com/qoax-community/qoax-infrastructure";
      labels = [ "qoax-community-management-plane" ];
    };
  };

  # The same key the root plane deploys with, as on the installer it starts from.
  users.users.root.openssh.authorizedKeys.keyFiles = [
    ./servacho-managment-plane/deploy-key.pub
  ];

  system.stateVersion = "26.05";
}
