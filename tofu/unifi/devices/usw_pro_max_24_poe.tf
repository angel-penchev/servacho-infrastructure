resource "unifi_device" "usw_pro_max_24_poe" {
  mac                = "9c:05:d6:e2:6b:1d"
  name               = "USW Pro Max 24 PoE"
  forget_on_destroy  = false
  disabled           = false
  flowctrl_enabled   = false
  jumboframe_enabled = false
  config_network = {
    type = "dhcp"
  }

  # ----------------------------------------------------------------------------
  # Note: As of v0.55.0, the ubiquiti-community/unifi provider does not yet have 
  # support for the ether_lighting block on devices or site settings. 
  #
  # PR in progress: https://github.com/ubiquiti-community/terraform-provider-unifi/pull/463
  # ----------------------------------------------------------------------------
  /*
  # Once merged, the following can be added to the resource below:
  #  ether_lighting {
  # mode       = "speed"
  # brightness = 100
  # behavior   = "steady"
  # led_mode   = "etherlighting"
  #  }
  */

  port_override {
    index           = 1
    name            = "LR-01"
    op_mode         = "switch"
    forward         = "customize"
    port_profile_id = var.port_profile_main_id
  }

  port_override {
    index           = 2
    name            = "LR-02"
    op_mode         = "switch"
    forward         = "customize"
    port_profile_id = var.port_profile_main_id
  }

  port_override {
    index           = 3
    name            = "LR-03"
    op_mode         = "switch"
    forward         = "customize"
    port_profile_id = var.port_profile_main_id
  }

  port_override {
    index           = 4
    name            = "LR-04"
    op_mode         = "switch"
    forward         = "customize"
    port_profile_id = var.port_profile_main_id
  }

  port_override {
    index           = 5
    name            = "LR-05"
    op_mode         = "switch"
    forward         = "customize"
    port_profile_id = var.port_profile_main_id
  }

  port_override {
    index           = 6
    name            = "LR-06"
    op_mode         = "switch"
    forward         = "customize"
    port_profile_id = var.port_profile_iot_id
  }

  port_override {
    index           = 7
    name            = "Balc-01"
    op_mode         = "switch"
    forward         = "customize"
    port_profile_id = var.port_profile_main_id
  }

  port_override {
    index           = 8
    name            = "Balc-02"
    op_mode         = "switch"
    forward         = "customize"
    port_profile_id = var.port_profile_main_id
  }

  port_override {
    index    = 9
    name     = "Port 9 (Disabled)"
    op_mode  = "switch"
    forward  = "disabled"
    poe_mode = "off"
  }

  port_override {
    index    = 10
    name     = "Port 10 (Disabled)"
    op_mode  = "switch"
    forward  = "disabled"
    poe_mode = "off"
  }

  port_override {
    index    = 11
    name     = "Port 11 (Disabled)"
    op_mode  = "switch"
    forward  = "disabled"
    poe_mode = "off"
  }

  port_override {
    index           = 12
    name            = "Servacho-Gosho-JetKVM"
    op_mode         = "switch"
    forward         = "customize"
    port_profile_id = var.port_profile_private_servers_id
  }

  port_override {
    index           = 13
    name            = "K-01"
    op_mode         = "switch"
    forward         = "customize"
    port_profile_id = var.port_profile_main_id
  }

  port_override {
    index           = 14
    name            = "K-02"
    op_mode         = "switch"
    forward         = "customize"
    port_profile_id = var.port_profile_main_id
  }

  port_override {
    index           = 15
    name            = "BR-07"
    op_mode         = "switch"
    forward         = "customize"
    port_profile_id = var.port_profile_main_id
  }

  port_override {
    index           = 16
    name            = "BR-08"
    op_mode         = "switch"
    forward         = "customize"
    port_profile_id = var.port_profile_main_id
  }

  port_override {
    index           = 17
    name            = "BR-01"
    op_mode         = "switch"
    forward         = "customize"
    port_profile_id = var.port_profile_main_id
  }

  port_override {
    index                 = 18
    name                  = "BR-02"
    op_mode               = "switch"
    forward               = "customize"
    native_networkconf_id = var.network_public_servers_id
  }

  port_override {
    index           = 19
    name            = "BR-03"
    op_mode         = "switch"
    forward         = "customize"
    port_profile_id = var.port_profile_main_id
  }

  port_override {
    index           = 20
    name            = "BR-04"
    op_mode         = "switch"
    forward         = "customize"
    port_profile_id = var.port_profile_public_servers_id
  }

  port_override {
    index           = 21
    name            = "BR-05"
    op_mode         = "switch"
    forward         = "customize"
    port_profile_id = var.port_profile_main_id
  }

  port_override {
    index           = 22
    name            = "BR-06"
    op_mode         = "switch"
    forward         = "customize"
    port_profile_id = var.port_profile_main_id
  }

  port_override {
    index           = 23
    name            = "LR-WiFi"
    op_mode         = "switch"
    forward         = "customize"
    port_profile_id = var.port_profile_unifi_devices_id
  }

  port_override {
    index           = 24
    name            = "BR-WiFi"
    op_mode         = "switch"
    forward         = "customize"
    port_profile_id = var.port_profile_unifi_devices_id
  }

  port_override {
    index   = 25
    name    = "SFP+ 1"
    op_mode = "switch"
    forward = "customize"
  }

  port_override {
    index           = 26
    name            = "UDM-Pro-Max"
    op_mode         = "switch"
    forward         = "customize"
    port_profile_id = var.port_profile_unifi_devices_id
  }
}
