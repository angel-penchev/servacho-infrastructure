# VLAN ID = third octet for every network with clients; management sits on 99.
# Per-network multicast_dns is derived by the controller from the site-wide Gateway
# mDNS Proxy scope (Main + IoT, see mdns.tf; upstream #282) -- not an independent knob.
#
# Two attributes appear on every network because the first real plan (CI run
# 34837315409, 2026-09-14, after import) showed them as drift otherwise:
# - setting_preference = "manual": what the controller stores for every network except
#   Main; the provider defaults to "auto" and would have flipped the other eight.
# - dhcp_guarding: the UI enables DHCP Guarding with the gateway as the only allowed
#   server on every VLAN it creates; without the block the plan would have switched
#   guarding OFF on seven networks.
#   FIXME(unifi): declared to MIRROR live only. The controller stores the trusted
#   servers as dhcpd_ip_1..3 (verified live 2026-09-14) and the provider reads them into
#   `servers` correctly, but its update PUT sends dhcpguard_enabled WITHOUT dhcpd_ip_*,
#   so the controller answers api.err.MissingIPAddress (400) and ANY update to a
#   guarded network fails (apply run 34843335300, unifi_network.unifi_devices). Until
#   that is fixed upstream, change guarded networks in the UI/API first and mirror here.

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

  multicast_dns      = false
  setting_preference = "manual"

  # DHCP is off (Phase 4, live dhcpd_enabled false).
  # FIXME(unifi): the provider reads a disabled DHCP server as a *null* dhcp_server
  #   block, so "off" cannot be declared -- `dhcp_server = { enabled = false, ... }`
  #   planned a perpetual update. Absent means off here; the range .1.6-.1.254 is
  #   still stored on the controller and would come back if DHCP were re-enabled.
}

# Management network for the UDM, switches and APs (runbook Phase 0, 2026-09-13).
# Created through the API, so it lacked three fields the UI sets on every network
# (auto_scale, lte_lan, gateway_type = "default") and had DHCP Guarding off. The first
# apply tried to bring it in line with the other eight and hit the dhcp_guarding write
# bug above; the same change was then made through the API (2026-09-14) and this block
# mirrors it.
resource "unifi_network" "unifi_devices" {
  name               = "UniFi Devices"
  purpose            = "corporate"
  vlan               = 99
  subnet             = "192.168.99.1/24"
  multicast_dns      = false
  setting_preference = "manual"

  dhcp_server = {
    enabled = true
    start   = "192.168.99.6"
    stop    = "192.168.99.254"
  }

  dhcp_guarding = {
    enabled = true
    servers = ["192.168.99.1"]
  }
}

# The one network the controller stores with setting_preference "auto" (it was created
# in the setup wizard, the others in the Networks page), so the attribute is left unset.
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

  dhcp_guarding = {
    enabled = true
    servers = ["192.168.2.1"]
  }
}

# purpose = "guest" only sticks while the network is in the Hotspot zone (firewall.tf).
resource "unifi_network" "guest" {
  name               = "Guest"
  purpose            = "guest"
  vlan               = 3
  subnet             = "192.168.3.1/24"
  multicast_dns      = false
  setting_preference = "manual"

  dhcp_server = {
    enabled = true
    start   = "192.168.3.6"
    stop    = "192.168.3.254"
  }

  dhcp_guarding = {
    enabled = true
    servers = ["192.168.3.1"]
  }
}

resource "unifi_network" "public_servers" {
  name               = "Public Servers"
  purpose            = "corporate"
  vlan               = 4
  subnet             = "192.168.4.1/24"
  multicast_dns      = false
  setting_preference = "manual"

  dhcp_server = {
    enabled = true
    start   = "192.168.4.6"
    stop    = "192.168.4.254"
  }

  dhcp_guarding = {
    enabled = true
    servers = ["192.168.4.1"]
  }
}

resource "unifi_network" "private_servers" {
  name               = "Private Servers"
  purpose            = "corporate"
  vlan               = 5
  subnet             = "192.168.5.1/24"
  multicast_dns      = false
  setting_preference = "manual"

  dhcp_server = {
    enabled = true
    start   = "192.168.5.6"
    stop    = "192.168.5.254"
  }

  dhcp_guarding = {
    enabled = true
    servers = ["192.168.5.1"]
  }
}

resource "unifi_network" "iot" {
  name               = "IoT"
  purpose            = "corporate"
  vlan               = 6
  subnet             = "192.168.6.1/24"
  multicast_dns      = true
  setting_preference = "manual"

  dhcp_server = {
    enabled = true
    start   = "192.168.6.6"
    stop    = "192.168.6.254"
  }

  dhcp_guarding = {
    enabled = true
    servers = ["192.168.6.1"]
  }
}

# A /23 (192.168.10.0-192.168.11.255); VLAN 11 no longer exists.
resource "unifi_network" "qoax_community_vps" {
  name               = "Qoax VPS"
  purpose            = "corporate"
  vlan               = 10
  subnet             = "192.168.10.1/23"
  multicast_dns      = false
  setting_preference = "manual"

  dhcp_server = {
    enabled = true
    start   = "192.168.10.11"
    stop    = "192.168.11.254"
  }

  dhcp_guarding = {
    enabled = true
    servers = ["192.168.10.1"]
  }
}

resource "unifi_network" "fmicodes_vps" {
  name               = "FMI{Codes} VPS"
  purpose            = "corporate"
  vlan               = 12
  subnet             = "192.168.12.1/24"
  multicast_dns      = false
  setting_preference = "manual"

  dhcp_server = {
    enabled = true
    start   = "192.168.12.6"
    stop    = "192.168.12.254"
  }

  dhcp_guarding = {
    enabled = true
    servers = ["192.168.12.1"]
  }
}
