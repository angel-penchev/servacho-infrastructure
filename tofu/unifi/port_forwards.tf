# 80 and 443, straight to soki, Qoax Community's temporary VM on VLAN 10
# (qoax-community/qoax-infrastructure's docs/soki.md), until the shared
# ingress VM (#83) exists and the forward moves there. It reached
# 192.168.5.58, Nginx Proxy Manager, which is shut down. On both WANs, since
# soki.qo.ax follows the active one; TCP, which is all HTTP needs.
#
# FIXME(unifi-ui-only): enabled true, log false, src_limiting_enabled false,
#   destination_ips [] -- all at controller defaults, no provider attribute.
resource "unifi_port_forward" "nginx_proxy" {
  name     = "soki web"
  protocol = "tcp"

  wan = {
    interface  = "both"
    ip_address = "any"
    port       = "80,443"
  }

  forward = {
    ip   = "192.168.10.41"
    port = "80,443"
  }
}

# Unity Intercom Server, public as intercom.qo.ax (docs/unity-intercom.md).
# Its Pro encryption closes the TCP port, so clients need UDP alone; with
# "Leave TCP Port Open" ticked this would have to be tcp_udp. On both WANs so
# it still answers while the gateway has failed over to WAN2 and the record
# has followed.
resource "unifi_port_forward" "unity_intercom" {
  name     = "Unity Intercom"
  protocol = "udp"

  wan = {
    interface  = "both"
    ip_address = "any"
    port       = "20101"
  }

  forward = {
    ip   = unifi_client.mac4o_mini.fixed_ip
    port = "20101"
  }
}

# os-tues, the operating systems class's machine, as <student>@vm.os.tues.qo.ax
# (docs/os-tues.md). On both WANs, as the intercom, so SSH still answers while
# the gateway has failed over to WAN2 and the record has followed.
resource "unifi_port_forward" "os_tues_ssh" {
  name     = "os-tues SSH"
  protocol = "tcp"

  wan = {
    interface  = "both"
    ip_address = "any"
    port       = "22"
  }

  forward = {
    ip   = "192.168.4.31"
    port = "22"
  }
}

# soki, Qoax Community's temporary VM on VLAN 10 until 2026-11-01, as
# ssh -p 2241 root@soki.qo.ax (qoax-community/qoax-infrastructure's
# docs/soki.md). 22 is os-tues's, so 2241. On both WANs, since the record
# follows the active one.
resource "unifi_port_forward" "soki_ssh" {
  name     = "soki SSH"
  protocol = "tcp"

  wan = {
    interface  = "both"
    ip_address = "any"
    port       = "2241"
  }

  forward = {
    ip   = "192.168.10.41"
    port = "22"
  }
}
