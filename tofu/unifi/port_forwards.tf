# The single live rule.
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
