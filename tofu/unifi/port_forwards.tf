# FIXME(unifi-ui-only): enabled true, log false, src_limiting_enabled false,
#   destination_ips [] -- all at controller defaults, no provider attribute.
resource "unifi_port_forward" "nginx_proxy" {
  name     = "NGINX Server"
  protocol = "tcp_udp"

  wan = {
    interface  = "wan"
    ip_address = "any"
    port       = "80,443"
  }

  forward = {
    ip   = "192.168.5.58"
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
