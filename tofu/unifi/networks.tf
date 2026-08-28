resource "unifi_network" "default" {
  lifecycle {
    ignore_changes = [domain_name]
  }
  name          = "Default"
  purpose       = "corporate"
  subnet        = "192.168.1.1/24"
  multicast_dns = false

  dhcp_server = {
    enabled = true
    start   = "192.168.1.6"
    stop    = "192.168.1.254"
  }
}

resource "unifi_network" "main" {
  lifecycle {
    ignore_changes = [domain_name]
  }
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
  lifecycle {
    ignore_changes = [domain_name]
  }
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
  lifecycle {
    ignore_changes = [domain_name]
  }
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
  lifecycle {
    ignore_changes = [domain_name]
  }
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
  lifecycle {
    ignore_changes = [domain_name]
  }
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

resource "unifi_network" "qoax_community_vps" {
  lifecycle {
    ignore_changes = [domain_name]
  }
  name          = "Qoax Community VPS"
  purpose       = "corporate"
  vlan          = 10
  subnet        = "192.168.10.1/24"
  multicast_dns = false

  dhcp_server = {
    enabled = true
    start   = "192.168.10.6"
    stop    = "192.168.10.254"
  }
}

resource "unifi_network" "qoax_community_broadcast_vps" {
  lifecycle {
    ignore_changes = [domain_name]
  }
  name          = "Qoax Community Broadcast VPS"
  purpose       = "corporate"
  vlan          = 11
  subnet        = "192.168.11.1/24"
  multicast_dns = false

  dhcp_server = {
    enabled = true
    start   = "192.168.11.6"
    stop    = "192.168.11.254"
  }
}

resource "unifi_network" "fmicodes_vps" {
  lifecycle {
    ignore_changes = [domain_name]
  }
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
