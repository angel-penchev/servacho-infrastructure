# Template for a Kubernetes control-plane node: a k3s server with embedded etcd
# that also runs workloads, which is what every prod node and the first dev
# node of qoaxhack are.
{ ... }:
{
  proxmox.qemuConf.name = "servacho-k3s-server";

  servacho.k3s = {
    enable = true;
    role = "server";
    # The qoax VPS network, VLAN 10 in tofu/unifi/networks.tf.
    clusterNetworks = [ "192.168.10.0/23" ];
    # Prod keeps its persistent volumes on Longhorn; the host side costs
    # nothing on a cluster that does not use it.
    longhorn.enable = true;
  };
}
