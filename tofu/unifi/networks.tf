# VLAN ID = third octet for every network with clients; management sits on 99.
# Per-network multicast_dns is derived by the controller from the site-wide Gateway
# mDNS Proxy scope (Main + IoT, see mdns.tf; upstream #282) -- not an independent knob.

# The built-in VLAN 1 network. Cannot be deleted or tagged, so it stays declared, but
# nothing uses it any more: management moved to VLAN 99 and the trunks' native network
# followed on 2026-09-14 (docs/unifi-mgmt-vlan-99-runbook.md, Phase 4). DHCP is off so
# anything that lands untagged on VLAN 1 gets no address. The two APs still *reference*
# it via mgmt_network_id -- that is the controller's way of saying "no override /
# untagged", see device_u7_pro_*.tf.
resource "unifi_network" "default" {
  name    = "Default (Untagged)"
  purpose = "corporate"
  subnet  = "192.168.1.1/24"

  multicast_dns = false

  dhcp_server = {
    enabled = false
    start   = "192.168.1.6"
    stop    = "192.168.1.254"
  }
}

# Management network for the UDM, switches and APs (runbook Phase 0, 2026-09-13).
resource "unifi_network" "unifi_devices" {
  name          = "UniFi Devices"
  purpose       = "corporate"
  vlan          = 99
  subnet        = "192.168.99.1/24"
  multicast_dns = false

  dhcp_server = {
    enabled = true
    start   = "192.168.99.6"
    stop    = "192.168.99.254"
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

# purpose = "guest" only sticks while the network is in the Hotspot zone (firewall.tf).
resource "unifi_network" "guest" {
  name          = "Guest"
  purpose       = "guest"
  vlan          = 3
  subnet        = "192.168.3.1/24"
  multicast_dns = false

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
  multicast_dns = false

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
  multicast_dns = false

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

# A /23 (192.168.10.0-192.168.11.255); VLAN 11 no longer exists.
resource "unifi_network" "qoax_community_vps" {
  name          = "Qoax VPS"
  purpose       = "corporate"
  vlan          = 10
  subnet        = "192.168.10.1/23"
  multicast_dns = false

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
  multicast_dns = false

  dhcp_server = {
    enabled = true
    start   = "192.168.12.6"
    stop    = "192.168.12.254"
  }
}
