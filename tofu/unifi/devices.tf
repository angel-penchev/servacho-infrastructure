resource "unifi_device" "udm_pro_max" {
  mac               = "28:70:4e:5c:b4:b2"
  name              = "Dream Machinacho Pro Max"
  forget_on_destroy = false
  disabled          = false

  port_override {
    index = 1
    name  = "Port 1"
    op_mode = "switch"
    native_networkconf_id = unifi_network.default.id
  }

  port_override {
    index = 10
    name  = "SFP+ 1"
    port_profile_id = unifi_port_profile.private_servers.id
    op_mode = "switch"
  }

  port_override {
    index = 11
    name  = "SFP+ 2"
    op_mode = "switch"
    native_networkconf_id = unifi_network.default.id
  }

  port_override {
    index = 2
    name  = "Port 2"
    op_mode = "switch"
    native_networkconf_id = unifi_network.default.id
  }

  port_override {
    index = 3
    name  = "Port 3"
    op_mode = "switch"
    native_networkconf_id = unifi_network.default.id
  }

  port_override {
    index = 4
    name  = "Port 4"
    op_mode = "switch"
    native_networkconf_id = unifi_network.default.id
  }

  port_override {
    index = 5
    name  = "Port 5"
    op_mode = "switch"
    native_networkconf_id = unifi_network.default.id
  }

  port_override {
    index = 6
    name  = "Port 6"
    op_mode = "switch"
    native_networkconf_id = unifi_network.default.id
  }

  port_override {
    index = 7
    name  = "Port 7"
    op_mode = "switch"
    native_networkconf_id = unifi_network.default.id
  }

  port_override {
    index = 8
    name  = "Port 8"
    op_mode = "switch"
    native_networkconf_id = unifi_network.default.id
  }

  port_override {
    index = 9
    name  = "Port 9"
    op_mode = "switch"
    native_networkconf_id = unifi_network.default.id
  }
}

resource "unifi_device" "usw_aggregation" {
  mac               = "1c:6a:1b:98:38:ee"
  name              = "USW Aggregation"
  forget_on_destroy = false
  disabled          = false

  port_override {
    index = 1
    name  = "SFP+ 1"
    port_profile_id = unifi_port_profile.private_servers.id
    op_mode = "switch"
  }

  port_override {
    index = 2
    name  = "SFP+ 2"
    op_mode = "switch"
  }

  port_override {
    index = 3
    name  = "SFP+ 3"
    op_mode = "switch"
  }

  port_override {
    index = 4
    name  = "SFP+ 4"
    op_mode = "switch"
  }

  port_override {
    index = 5
    name  = "SFP+ 5"
    op_mode = "switch"
  }

  port_override {
    index = 6
    name  = "SFP+ 6"
    op_mode = "switch"
  }

  port_override {
    index = 7
    name  = "SFP+ 7"
    op_mode = "switch"
  }

  port_override {
    index = 8
    name  = "SFP+ 8"
    op_mode = "switch"
  }
}

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
  #    mode       = "speed"
  #    brightness = 100
  #    behavior   = "steady"
  #    led_mode   = "etherlighting"
  #  }
  */

  port_override {
    index = 1
    name  = "LR-01"
    port_profile_id = unifi_port_profile.main.id
    op_mode = "switch"
  }

  port_override {
    index = 2
    name  = "LR-02"
    port_profile_id = unifi_port_profile.main.id
    op_mode = "switch"
  }

  port_override {
    index = 3
    name  = "LR-03"
    port_profile_id = unifi_port_profile.main.id
    op_mode = "switch"
  }

  port_override {
    index = 4
    name  = "LR-04"
    port_profile_id = unifi_port_profile.main.id
    op_mode = "switch"
  }

  port_override {
    index = 5
    name  = "LR-05"
    port_profile_id = unifi_port_profile.main.id
    op_mode = "switch"
  }

  port_override {
    index = 6
    name  = "LR-06"
    port_profile_id = unifi_port_profile.iot.id
    op_mode = "switch"
  }

  port_override {
    index = 7
    name  = "Balc-01"
    port_profile_id = unifi_port_profile.main.id
    op_mode = "switch"
  }

  port_override {
    index = 8
    name  = "Balc-02"
    port_profile_id = unifi_port_profile.main.id
    op_mode = "switch"
  }

  port_override {
    index = 9
    name  = "Port 9"
    forward = "disabled"
    op_mode = "switch"
  }

  port_override {
    index = 10
    name  = "Port 10"
    forward = "disabled"
    op_mode = "switch"
  }

  port_override {
    index = 11
    name  = "Port 11"
    port_profile_id = unifi_port_profile.public_servers.id
    op_mode = "switch"
  }

  port_override {
    index = 12
    name  = "Port 12"
    op_mode = "switch"
    native_networkconf_id = unifi_network.default.id
  }

  port_override {
    index = 13
    name  = "K-01"
    port_profile_id = unifi_port_profile.main.id
    op_mode = "switch"
  }

  port_override {
    index = 14
    name  = "K-02"
    port_profile_id = unifi_port_profile.main.id
    op_mode = "switch"
  }

  port_override {
    index = 15
    name  = "BR-07"
    port_profile_id = unifi_port_profile.main.id
    op_mode = "switch"
  }

  port_override {
    index = 16
    name  = "BR-08"
    port_profile_id = unifi_port_profile.main.id
    op_mode = "switch"
  }

  port_override {
    index = 17
    name  = "BR-01"
    port_profile_id = unifi_port_profile.main.id
    op_mode = "switch"
  }

  port_override {
    index = 18
    name  = "BR-02"
    op_mode = "switch"
    native_networkconf_id = unifi_network.public_servers.id
  }

  port_override {
    index = 19
    name  = "BR-03"
    port_profile_id = unifi_port_profile.main.id
    op_mode = "switch"
  }

  port_override {
    index = 20
    name  = "BR-04"
    port_profile_id = unifi_port_profile.public_servers.id
    op_mode = "switch"
  }

  port_override {
    index = 21
    name  = "BR-05"
    port_profile_id = unifi_port_profile.main.id
    op_mode = "switch"
  }

  port_override {
    index = 22
    name  = "BR-06"
    port_profile_id = unifi_port_profile.main.id
    op_mode = "switch"
  }

  port_override {
    index = 23
    name  = "LR-WiFi"
    op_mode = "switch"
    native_networkconf_id = unifi_network.default.id
  }

  port_override {
    index = 24
    name  = "BR-WiFi"
    op_mode = "switch"
    native_networkconf_id = unifi_network.default.id
  }

  port_override {
    index = 25
    name  = "SFP+ 1"
    op_mode = "switch"
  }

  port_override {
    index = 26
    name  = "SFP+ 2"
    op_mode = "switch"
  }
}

resource "unifi_device" "u7_pro_bedroom" {
  mac               = "9c:05:d6:d9:af:65"
  name              = "Bedroom U7-Pro"
  forget_on_destroy = false
  disabled          = false
}

resource "unifi_device" "u7_pro_living_room" {
  mac               = "9c:05:d6:d9:ad:79"
  name              = "Living Room U7-Pro"
  forget_on_destroy = false
  disabled          = false
}
