# Template for a Kubernetes worker node: a k3s agent that joins an existing
# server and only runs workloads, as qoaxhack's second dev node does.
{ ... }:
{
  proxmox.qemuConf.name = "servacho-k3s-agent";

  servacho.k3s = {
    enable = true;
    role = "agent";
    # The qoax VPS network, VLAN 10 in tofu/unifi/networks.tf.
    clusterNetworks = [ "192.168.10.0/23" ];
    # Same host side as the server template, so an agent can hold Longhorn
    # replicas if it is ever added to a cluster that uses it.
    longhorn.enable = true;
  };
}
