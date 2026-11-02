# VLAN ID = third octet for every network with clients; management sits on 99.
# multicast_dns and the Gateway mDNS Proxy's network list (`mdns` in settings.tf, notes
# in mdns.tf) are one setting seen from two sides: true on Main and IoT only. The
# provider never writes the list, so the scope is chosen with multicast_dns. Read never
# refreshes multicast_dns after import (upstream #282), so a UI change does not show in
# a plan, and neither does a write the gateway ignored: change the scope in the UI, then
# mirror it here.
#
# setting_preference = "manual" is what the controller stores for every network created
# on the Networks page (Main came from the setup wizard and is "auto"). Every network
# declares it: the provider plans "manual" for a guarded corporate or guest network that
# leaves it unset (upstream #419).
# dhcp_guarding mirrors the UI, which enables DHCP Guarding with the gateway as the only
# trusted server on every VLAN it creates.
# FIXME(unifi): Read fills dhcp_guarding only on import (with guarding on) or once state
#   holds the block, so a network imported with guarding off and guarded later in the
#   UI plans `+ dhcp_guarding` until a `state rm` and re-import adopt it with no write
#   (docs/unifi-import-plan.md); an apply would rewrite the four guard keys instead.

# The built-in VLAN 1 network. Cannot be deleted or tagged, so it stays declared, but
# nothing uses it: management and the trunks' native network are VLAN 99
# (docs/unifi-mgmt-vlan-99-runbook.md). DHCP is off so anything that lands untagged on
# VLAN 1 gets no address. The two APs still *reference* it via mgmt_network_id -- that
# is the controller's way of saying "no override / untagged", see device_u7_pro_*.tf.
resource "unifi_network" "default" {
  name    = "Default (Untagged)"
  purpose = "corporate"
  subnet  = "192.168.1.1/24"

  multicast_dns      = false
  setting_preference = "manual"

  # DHCP is off. FIXME(unifi): Read fills dhcp_server only on an import with DHCP on or
  #   once state holds the block, so "off" cannot be adopted without a write: declaring
  #   `enabled = false` makes one apply send every dhcp_server key except boot. Left out,
  #   the block is unmanaged and no update sends its keys. The stored range .1.6-.1.254
  #   would come back if DHCP were re-enabled.
}

# Management network for the UDM, switches and APs (docs/unifi-mgmt-vlan-99-runbook.md).
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
# in the setup wizard, the others in the Networks page). Declared, or the provider plans
# "manual" because dhcp_guarding is on; the explicit "auto" draws a plan warning
# (upstream #419), so guarded changes to Main stay in the UI.
resource "unifi_network" "main" {
  name               = "Main"
  purpose            = "corporate"
  vlan               = 2
  subnet             = "192.168.2.1/24"
  multicast_dns      = true
  setting_preference = "auto"

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

# A /23 (192.168.10.0-192.168.11.255). .2-.99 are for static hosts (the
# management plane on .15, the clusters from .21); DHCP, which a VM's
# installer needs, starts above them (changed in the UI on 2026-10-04,
# docs/unifi-browser-changes.md).
resource "unifi_network" "qoax_community_vps" {
  name               = "Qoax VPS"
  purpose            = "corporate"
  vlan               = 10
  subnet             = "192.168.10.1/23"
  multicast_dns      = false
  setting_preference = "manual"

  # Off, or the DHCP range below cannot differ from the whole subnet.
  auto_scale = false

  dhcp_server = {
    enabled = true
    start   = "192.168.10.100"
    stop    = "192.168.11.254"
  }

  dhcp_guarding = {
    enabled = true
    servers = ["192.168.10.1"]
  }
}

# .2-.99 are for static hosts (the management plane on .15); DHCP starts above.
resource "unifi_network" "fmicodes_vps" {
  name               = "FMI{Codes} VPS"
  purpose            = "corporate"
  vlan               = 12
  subnet             = "192.168.12.1/24"
  multicast_dns      = false
  setting_preference = "manual"

  # Off, or the DHCP range below cannot differ from the whole subnet.
  auto_scale = false

  dhcp_server = {
    enabled = true
    start   = "192.168.12.100"
    stop    = "192.168.12.254"
  }

  dhcp_guarding = {
    enabled = true
    servers = ["192.168.12.1"]
  }
}
