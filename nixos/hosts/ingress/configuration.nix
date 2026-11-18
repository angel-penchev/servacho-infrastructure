# ingress: HAProxy routing 80 and 443 to tenants by name (docs/ingress.md).
{ lib, ... }:
let
  # The one copy of the VM's address, which tofu/ reads too. Moving the VM
  # takes more than an edit of vm.json (docs/ingress.md, Known gaps).
  vm = lib.importJSON ./vm.json;
  # The root plane, which deploys the VM, and the administrators' networks.
  sshSources = [ "192.168.5.15" ] ++ import ../../admin-sources.nix;
in
{
  imports = [ ./haproxy.nix ];

  networking.hostName = "ingress";
  networking.useDHCP = false;
  systemd.network = {
    enable = true;
    networks."10-lan" = {
      matchConfig.Type = "ether";
      address = [ "${vm.address}/${toString vm.prefix_length}" ];
      gateway = [ vm.gateway ];
      dns = [
        "1.1.1.1"
        "1.0.0.1"
      ];
    };
  };

  servacho.ssh.sources = sshSources;

  # The forward keeps the visitor's address, and NAT loopback comes from the
  # gateway. The exporter on 8405 admits the same sources as SSH.
  networking.firewall.extraInputRules = ''
    tcp dport { 80, 443 } ip saddr ${vm.gateway} accept
    tcp dport { 80, 443 } ip saddr != { 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16 } accept
    tcp dport 8405 ip saddr { ${lib.concatStringsSep ", " sshSources} } accept
  '';

  users.users.root.openssh.authorizedKeys.keyFiles = [
    ../servacho-managment-plane/deploy-key.pub
    ../../keys/servacho.pub
  ];

  system.stateVersion = "26.05";
}
