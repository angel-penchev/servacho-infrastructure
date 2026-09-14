# Port forwards mirror the live controller as of 2026-09-13: a single rule. The
# pre-reset code also had public SSH (2242/2243) and Postgres (5432) forwards to the
# fmicodes nodes and two count = 0 placeholders (Minecraft, intercom UDP ranges); none
# were recreated after the rebuild and all were dropped here by decision.
#
# Live-only fields with no provider attribute, all at their defaults: enabled true,
# log false, src_limiting_enabled false, destination_ips [].
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
