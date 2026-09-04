resource "unifi_device" "udm_pro_max" {
  mac               = "28:70:4e:5c:b4:b2"
  name              = "Dream Machinacho Pro Max"
  forget_on_destroy = false
  disabled          = false

  port_override {
    index                 = 1
    name                  = "Port 1"
    op_mode               = "switch"
    forward               = "customize"
    native_networkconf_id = var.wan_secondary_id
  }

  port_override {
    index    = 2
    name     = "Port 2 (Disabled)"
    op_mode  = "switch"
    forward  = "disabled"
    poe_mode = "off"
  }

  port_override {
    index    = 3
    name     = "Port 3 (Disabled)"
    op_mode  = "switch"
    forward  = "disabled"
    poe_mode = "off"
  }

  port_override {
    index    = 4
    name     = "Port 4 (Disabled)"
    op_mode  = "switch"
    forward  = "disabled"
    poe_mode = "off"
  }

  port_override {
    index    = 5
    name     = "Port 5 (Disabled)"
    op_mode  = "switch"
    forward  = "disabled"
    poe_mode = "off"
  }

  port_override {
    index    = 6
    name     = "Port 6 (Disabled)"
    op_mode  = "switch"
    forward  = "disabled"
    poe_mode = "off"
  }

  port_override {
    index    = 7
    name     = "Port 7 (Disabled)"
    op_mode  = "switch"
    forward  = "disabled"
    poe_mode = "off"
  }

  port_override {
    index    = 8
    name     = "Port 8 (Disabled)"
    op_mode  = "switch"
    forward  = "disabled"
    poe_mode = "off"
  }

  port_override {
    index                 = 9
    name                  = "Port 9"
    op_mode               = "switch"
    forward               = "customize"
    native_networkconf_id = var.wan_primary_id
  }

  port_override {
    index           = 10
    name            = "SFP+ 1"
    op_mode         = "switch"
    forward         = "customize"
    port_profile_id = var.port_profile_private_servers_id
  }

  port_override {
    index           = 11
    name            = "USW-Aggregation"
    op_mode         = "switch"
    forward         = "customize"
    port_profile_id = var.port_profile_unifi_devices_id
  }
}
