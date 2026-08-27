resource "unifi_network" "default" {
  name             = "Default"
  purpose          = "corporate"
  subnet           = "192.168.1.1/24"
  dhcp_enabled     = true
  dhcp_start       = "192.168.1.6"
  dhcp_stop        = "192.168.1.254"
  dhcp_v6_start    = "::2"
  dhcp_v6_stop     = "::7d1"
  ipv6_pd_start    = "::2"
  ipv6_pd_stop     = "::7d1"
  ipv6_ra_priority = "high"
  multicast_dns    = false
}

resource "unifi_network" "main" {
  name             = "Main"
  purpose          = "corporate"
  vlan_id          = 2
  subnet           = "192.168.2.1/24"
  dhcp_enabled     = true
  dhcp_start       = "192.168.2.6"
  dhcp_stop        = "192.168.2.254"
  dhcp_v6_start    = "::2"
  dhcp_v6_stop     = "::7d1"
  ipv6_pd_start    = "::2"
  ipv6_pd_stop     = "::7d1"
  ipv6_ra_priority = "high"
  multicast_dns    = true
}

resource "unifi_network" "guest" {
  name             = "Guest"
  purpose          = "guest"
  vlan_id          = 3
  subnet           = "192.168.3.1/24"
  dhcp_enabled     = true
  dhcp_start       = "192.168.3.6"
  dhcp_stop        = "192.168.3.254"
  dhcp_v6_start    = "::2"
  dhcp_v6_stop     = "::7d1"
  ipv6_pd_start    = "::2"
  ipv6_pd_stop     = "::7d1"
  ipv6_ra_priority = "high"
  multicast_dns    = true
}

resource "unifi_network" "public_servers" {
  name             = "Public Servers"
  purpose          = "corporate"
  vlan_id          = 4
  subnet           = "192.168.4.1/24"
  dhcp_enabled     = true
  dhcp_start       = "192.168.4.6"
  dhcp_stop        = "192.168.4.254"
  dhcp_v6_start    = "::2"
  dhcp_v6_stop     = "::7d1"
  ipv6_pd_start    = "::2"
  ipv6_pd_stop     = "::7d1"
  ipv6_ra_priority = "high"
  multicast_dns    = false
}

resource "unifi_network" "private_servers" {
  name             = "Private Servers"
  purpose          = "corporate"
  vlan_id          = 5
  subnet           = "192.168.5.1/24"
  dhcp_enabled     = true
  dhcp_start       = "192.168.5.6"
  dhcp_stop        = "192.168.5.254"
  dhcp_v6_start    = "::2"
  dhcp_v6_stop     = "::7d1"
  ipv6_pd_start    = "::2"
  ipv6_pd_stop     = "::7d1"
  ipv6_ra_priority = "high"
  multicast_dns    = false
}

resource "unifi_network" "iot" {
  name             = "IoT"
  purpose          = "corporate"
  vlan_id          = 6
  subnet           = "192.168.6.1/24"
  dhcp_enabled     = true
  dhcp_start       = "192.168.6.6"
  dhcp_stop        = "192.168.6.254"
  dhcp_v6_start    = "::2"
  dhcp_v6_stop     = "::7d1"
  ipv6_pd_start    = "::2"
  ipv6_pd_stop     = "::7d1"
  ipv6_ra_priority = "high"
  multicast_dns    = true
}

resource "unifi_network" "qoax_community_vps" {
  name             = "Qoax Community VPS"
  purpose          = "corporate"
  vlan_id          = 10
  subnet           = "192.168.10.1/24"
  dhcp_enabled     = true
  dhcp_start       = "192.168.10.6"
  dhcp_stop        = "192.168.10.254"
  dhcp_v6_start    = "::2"
  dhcp_v6_stop     = "::7d1"
  ipv6_pd_start    = "::2"
  ipv6_pd_stop     = "::7d1"
  ipv6_ra_priority = "high"
  multicast_dns    = false
}

resource "unifi_network" "qoax_community_broadcast_vps" {
  name             = "Qoax Community Broadcast VPS"
  purpose          = "corporate"
  vlan_id          = 11
  subnet           = "192.168.11.1/24"
  dhcp_enabled     = true
  dhcp_start       = "192.168.11.6"
  dhcp_stop        = "192.168.11.254"
  dhcp_v6_start    = "::2"
  dhcp_v6_stop     = "::7d1"
  ipv6_pd_start    = "::2"
  ipv6_pd_stop     = "::7d1"
  ipv6_ra_priority = "high"
  multicast_dns    = false
}

resource "unifi_network" "fmicodes_vps" {
  name             = "FMI{Codes} VPS"
  purpose          = "corporate"
  vlan_id          = 12
  subnet           = "192.168.12.1/24"
  dhcp_enabled     = true
  dhcp_start       = "192.168.12.6"
  dhcp_stop        = "192.168.12.254"
  dhcp_v6_start    = "::2"
  dhcp_v6_stop     = "::7d1"
  ipv6_pd_start    = "::2"
  ipv6_pd_stop     = "::7d1"
  ipv6_ra_priority = "high"
  multicast_dns    = false
}
