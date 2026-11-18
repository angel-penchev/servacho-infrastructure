# A check for each host that the root plane deploys over SSH from
# 192.168.5.15. The root plane installs and deploys these hosts with
# OpenTofu. It also unseals the tenant planes' OpenBao and runs
# os-tues-students over SSH. If servacho.ssh.sources leaves the address out,
# no deploy reaches the host. Then even the deploy of a fix cannot undo the
# list. flake.nix adds this file to every host except the root plane and the
# installer.
{ config, lib, ... }:
let
  # hosts/servacho-managment-plane/configuration.nix
  deployer = "192.168.5.15";
  sources = config.servacho.ssh.sources;
in
{
  assertions = [
    {
      # infrastructure-reusables reports an unset list itself. A CIDR that
      # holds the address does not count, so each list stays narrow.
      assertion = sources == null || sources == "any" || lib.elem deployer sources;
      message = ''servacho.ssh.sources leaves out ${deployer}, the root plane, which deploys this host over SSH. Add "${deployer}" itself to the list, or set the option to "any". A CIDR that holds the address does not count.'';
    }
  ];
}
