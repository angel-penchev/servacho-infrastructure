# VLAN ID = third octet for every network with clients; management sits on 99.
# Per-network multicast_dns is derived by the controller from the site-wide Gateway
# mDNS Proxy scope (Main + IoT, see mdns.tf; upstream #282) -- not an independent knob.
#
# setting_preference = "manual" is what the controller stores for every network created
# on the Networks page (Main came from the setup wizard and is "auto"); the provider
# defaults to "auto". dhcp_guarding mirrors the UI, which enables DHCP Guarding with the
# gateway as the only trusted server on every VLAN it creates.
# FIXME(unifi): dhcp_guarding is declared to MIRROR live only -- it is write-broken and
#   read-sticky at v0.55.0. The update PUT sends dhcpguard_enabled without the trusted
#   servers (dhcpd_ip_1..3), which the controller rejects with api.err.MissingIPAddress,
#   so ANY update to a guarded network fails. Read fills the block only on import or when
#   state already has it, so a network imported with guarding off needs `state rm` and a
#   re-import once guarding is on (docs/unifi-import-plan.md). Change guarded networks in
#   the UI/API first and mirror here.

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

  # DHCP is off. FIXME(unifi): the provider reads a disabled DHCP server as a *null*
  #   dhcp_server block, so "off" cannot be declared -- `enabled = false` plans a
  #   perpetual update. Absent means off here; the stored range .1.6-.1.254 would come
  #   back if DHCP were re-enabled.
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
