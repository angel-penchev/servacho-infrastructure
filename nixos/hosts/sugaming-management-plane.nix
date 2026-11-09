# The SUGAMING management plane: OpenTofu, OpenBao and the runner for the
# SUGAMING tenant, on its VPS network. Installed from
# images/installer.nix and deployed by tofu/organisation/plane.tf; the
# VM's hardware and disk layout come from infrastructure-reusables.
{ ... }:
{
  networking.hostName = "sugaming-management-plane";

  servacho.managementPlane = {
    enable = true;
    # A management plane takes .15 of its VLAN. VLAN 13 is a /24
    # (tofu/unifi/networks.tf); id rule: 13 + 015 = VM 13015.
    network = {
      address = "192.168.13.15";
      prefixLength = 24;
      gateway = "192.168.13.1";
    };
    # The runner joins once the tenant's infrastructure repository exists;
    # until then the plane is an OpenBao and a tofu host reached over SSH.
    runner.enable = false;
  };

  # The same key the root plane deploys with, as on the installer it starts
  # from, and the administrators' workstations. A tenant plane has no other
  # user, so administrators log in as root.
  users.users.root.openssh.authorizedKeys.keyFiles = [
    ./servacho-managment-plane/deploy-key.pub
    ../keys/servacho.pub
  ];

  system.stateVersion = "26.05";
}
