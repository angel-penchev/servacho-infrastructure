# The untagged/native LAN. Carries UniFi device management only; every host-facing
# port lives behind the "Host Device" profile, so nothing untrusted lands here.
#
# TODO(vlan1): decide whether to move device management off the native VLAN. See
# docs/unifi-manual-vs-tofu.md §2 for the recommendation (defer until v0.56.0 —
# mgmt_network_id requires the target VLAN to be tagged on the uplink first, and
# device updates are unreliable on the pinned provider).
resource "unifi_network" "default" {
  name    = "UniFi Devices"
  purpose = "corporate"
  subnet  = "192.168.1.1/24"

  # multicast_dns is true on every network here to match live. The flag is cosmetic on
  # UniFi OS gateways -- they ignore it (upstream #282) -- and what is actually in force
  # is the site-wide Gateway mDNS Proxy, set to mode="all" / enabled_for="all". See
  # ../system/mdns.tf for that setting and why it cannot be managed in code.
  multicast_dns = true

  dhcp_server = {
    enabled = true
    start   = "192.168.1.6"
    stop    = "192.168.1.254"
  }
}

resource "unifi_network" "main" {
  name          = "Main"
  purpose       = "corporate"
  vlan          = 2
  subnet        = "192.168.2.1/24"
  multicast_dns = true

  dhcp_server = {
    enabled = true
    start   = "192.168.2.6"
    stop    = "192.168.2.254"
  }
}

resource "unifi_network" "guest" {
  name          = "Guest"
  purpose       = "guest"
  vlan          = 3
  subnet        = "192.168.3.1/24"
  multicast_dns = true

  dhcp_server = {
    enabled = true
    start   = "192.168.3.6"
    stop    = "192.168.3.254"
  }
}

resource "unifi_network" "public_servers" {
  name          = "Public Servers"
  purpose       = "corporate"
  vlan          = 4
  subnet        = "192.168.4.1/24"
  multicast_dns = true

  dhcp_server = {
    enabled = true
    start   = "192.168.4.6"
    stop    = "192.168.4.254"
  }
}

resource "unifi_network" "private_servers" {
  name          = "Private Servers"
  purpose       = "corporate"
  vlan          = 5
  subnet        = "192.168.5.1/24"
  multicast_dns = true

  dhcp_server = {
    enabled = true
    start   = "192.168.5.6"
    stop    = "192.168.5.254"
  }
}

resource "unifi_network" "iot" {
  name          = "IoT"
  purpose       = "corporate"
  vlan          = 6
  subnet        = "192.168.6.1/24"
  multicast_dns = true

  dhcp_server = {
    enabled = true
    start   = "192.168.6.6"
    stop    = "192.168.6.254"
  }
}

# Widened to a /23 during the 2026-09 rebuild: this single network now spans
# 192.168.10.0-192.168.11.255 and absorbs what used to be the separate
# "Qoax Community Broadcast VPS" network on VLAN 11. VLAN 11 no longer exists.
resource "unifi_network" "qoax_community_vps" {
  name          = "Qoax VPS"
  purpose       = "corporate"
  vlan          = 10
  subnet        = "192.168.10.1/23"
  multicast_dns = true

  dhcp_server = {
    enabled = true
    start   = "192.168.10.11"
    stop    = "192.168.11.254"
  }
}

resource "unifi_network" "fmicodes_vps" {
  name          = "FMI{Codes} VPS"
  purpose       = "corporate"
  vlan          = 12
  subnet        = "192.168.12.1/24"
  multicast_dns = true

  dhcp_server = {
    enabled = true
    start   = "192.168.12.6"
    stop    = "192.168.12.254"
  }
}
