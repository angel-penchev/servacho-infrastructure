resource "unifi_port_profile" "main" {
  name                  = "Main"
  forward               = "customize"
  native_networkconf_id = unifi_network.guest.id
  poe_mode              = "auto"
  autoneg               = true
  dot1x_ctrl            = "auto"
  tagged_vlan_mgmt      = "auto"
  stp_port_mode         = false
}

resource "unifi_port_profile" "public_servers" {
  name                  = "Public Servers"
  forward               = "customize"
  native_networkconf_id = unifi_network.public_servers.id
  poe_mode              = "auto"
  autoneg               = true
  dot1x_ctrl            = "force_authorized"
  tagged_vlan_mgmt      = "auto"
  stp_port_mode         = false
}

resource "unifi_port_profile" "private_servers" {
  name                  = "Private Servers"
  forward               = "customize"
  native_networkconf_id = unifi_network.private_servers.id
  poe_mode              = "auto"
  autoneg               = true
  dot1x_ctrl            = "force_authorized"
  tagged_vlan_mgmt      = "auto"
  stp_port_mode         = false
}

resource "unifi_port_profile" "iot" {
  name                  = "IoT"
  forward               = "customize"
  native_networkconf_id = unifi_network.iot.id
  poe_mode              = "auto"
  autoneg               = true
  dot1x_ctrl            = "force_authorized"
  tagged_vlan_mgmt      = "auto"
  stp_port_mode         = false
}

resource "unifi_port_profile" "unifi_devices" {
  name                  = "UniFi Devices"
  forward               = "all"
  native_networkconf_id = unifi_network.default.id
  poe_mode              = "auto"
  autoneg               = true
  dot1x_ctrl            = "auto"
  tagged_vlan_mgmt      = "auto"
  stp_port_mode         = true
}


resource "unifi_port_profile" "disabled" {
  name     = "Disabled Port"
  forward  = "disabled"
  poe_mode = "off"
}
