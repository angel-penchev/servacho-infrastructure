resource "unifi_device" "usw_pro_max_24_poe" {
  mac                = "9c:05:d6:e2:6b:1d"
  name               = "USW Pro Max 24 PoE"
  forget_on_destroy  = false
  disabled           = false
  flowctrl_enabled   = false
  jumboframe_enabled = false

  # FIXME(unifi): The ubiquiti-community/unifi provider has a bug where SFP+ fiber ports
  # omit RJ45-specific attributes (autoneg, stormctrl_*, lldpmed_enabled) from the API response.
  # This causes schema validation crashes ("inconsistent result after apply").
  # Keep this ignore_changes block until the provider is patched.
  lifecycle {
    ignore_changes = [port_override]
  }

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
    port_profile_id = var.port_profile_main_id
    op_mode         = "switch"
  }

  port_override {
    index           = 2
    name            = "LR-02"
    port_profile_id = var.port_profile_main_id
    op_mode         = "switch"
  }

  port_override {
    index           = 3
    name            = "LR-03"
    port_profile_id = var.port_profile_main_id
    op_mode         = "switch"
  }

  port_override {
    index           = 4
    name            = "LR-04"
    port_profile_id = var.port_profile_main_id
    op_mode         = "switch"
  }

  port_override {
    index           = 5
    name            = "LR-05"
    port_profile_id = var.port_profile_main_id
    op_mode         = "switch"
  }

  port_override {
    index           = 6
    name            = "LR-06"
    port_profile_id = var.port_profile_iot_id
    op_mode         = "switch"
  }

  port_override {
    index           = 7
    name            = "Balc-01"
    port_profile_id = var.port_profile_main_id
    op_mode         = "switch"
  }

  port_override {
    index           = 8
    name            = "Balc-02"
    port_profile_id = var.port_profile_main_id
    op_mode         = "switch"
  }

  port_override {
    index   = 9
    name    = "Port 9"
    forward = "disabled"
    op_mode = "switch"
  }

  port_override {
    index   = 10
    name    = "Port 10"
    forward = "disabled"
    op_mode = "switch"
  }

  port_override {
    index   = 11
    name    = "Port 11"
    forward = "disabled"
    op_mode = "switch"
  }

  port_override {
    index           = 12
    name            = "Servacho-Gosho-JetKVM"
    port_profile_id = var.port_profile_private_servers_id
    op_mode         = "switch"
  }

  port_override {
    index           = 13
    name            = "K-01"
    port_profile_id = var.port_profile_main_id
    op_mode         = "switch"
  }

  port_override {
    index           = 14
    name            = "K-02"
    port_profile_id = var.port_profile_main_id
    op_mode         = "switch"
  }

  port_override {
    index           = 15
    name            = "BR-07"
    port_profile_id = var.port_profile_main_id
    op_mode         = "switch"
  }

  port_override {
    index           = 16
    name            = "BR-08"
    port_profile_id = var.port_profile_main_id
    op_mode         = "switch"
  }

  port_override {
    index           = 17
    name            = "BR-01"
    port_profile_id = var.port_profile_main_id
    op_mode         = "switch"
  }

  port_override {
    index                 = 18
    name                  = "BR-02"
    op_mode               = "switch"
    native_networkconf_id = var.network_public_servers_id
  }

  port_override {
    index           = 19
    name            = "BR-03"
    port_profile_id = var.port_profile_main_id
    op_mode         = "switch"
  }

  port_override {
    index           = 20
    name            = "BR-04"
    port_profile_id = var.port_profile_public_servers_id
    op_mode         = "switch"
  }

  port_override {
    index           = 21
    name            = "BR-05"
    port_profile_id = var.port_profile_main_id
    op_mode         = "switch"
  }

  port_override {
    index           = 22
    name            = "BR-06"
    port_profile_id = var.port_profile_main_id
    op_mode         = "switch"
  }

  port_override {
    index                 = 23
    name                  = "LR-WiFi"
    op_mode               = "switch"
    native_networkconf_id = var.network_default_id
  }

  port_override {
    index                 = 24
    name                  = "BR-WiFi"
    op_mode               = "switch"
    native_networkconf_id = var.network_default_id
  }

  port_override {
    index   = 25
    name    = "SFP+ 1"
    op_mode = "switch"
  }

  port_override {
    index   = 26
    name    = "SFP+ 2"
    op_mode = "switch"
  }
}
