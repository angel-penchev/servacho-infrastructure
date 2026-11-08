# ingress: the VM the gateway forwards the internet's 80 and 443 to. HAProxy
# on it sends each connection to its tenant's servers by name, without ending
# TLS (haproxy.nix, docs/ingress.md). Installed and deployed by
# tofu/ingress.tf like os-tues; the VM's hardware and disk layout come from
# infrastructure-reusables.
{ ... }:
let
  # Public Servers, VLAN 4 (tofu/unifi/networks.tf), in the Dmz zone: the
  # internet reaches it through the forward and Internal can reach it, but it
  # reaches Internal only where a tenant's policy opens the way
  # (tofu/unifi/ingress.tf). Id rule: 4 + 016 = VM 4016.
  address = "192.168.4.16";
  prefixLength = 24;
  gateway = "192.168.4.1";
in
{
  imports = [ ./haproxy.nix ];

  networking.hostName = "ingress";
  networking.useDHCP = false;
  systemd.network = {
    enable = true;
    networks."10-lan" = {
      matchConfig.Type = "ether";
      address = [ "${address}/${toString prefixLength}" ];
      gateway = [ gateway ];
      dns = [
        "1.1.1.1"
        "1.0.0.1"
      ];
    };
  };

  # Everything the VM accepts, as nftables rules beside the base module's.
  # The forward changes only the destination, so 80 and 443 see the
  # visitor's own address: they admit any address outside the private
  # ranges, and the gateway's, which NAT loopback comes from; no other
  # private address. SSH and HAProxy's exporter (8405, haproxy.nix) admit
  # the root plane, which deploys the VM, Main, and the Teleport, OpenVPN
  # and WireGuard subnets (tofu/unifi/vpn.tf).
  services.openssh.openFirewall = false;
  networking.firewall.extraInputRules = ''
    tcp dport { 80, 443 } ip saddr ${gateway} accept
    tcp dport { 80, 443 } ip saddr != { 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16 } accept
    tcp dport { 22, 8405 } ip saddr { 192.168.5.15, 192.168.2.0/24, 192.168.7.0/24, 192.168.8.0/24, 192.168.9.0/24 } accept
  '';

  # The key the root plane deploys with, as on the installer it starts from,
  # and the administrators' workstations.
  users.users.root.openssh.authorizedKeys.keyFiles = [
    ../servacho-managment-plane/deploy-key.pub
    ../../keys/servacho.pub
  ];

  system.stateVersion = "26.05";
}
