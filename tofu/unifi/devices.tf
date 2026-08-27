resource "unifi_device" "udm_pro_max" {
  mac               = "28:70:4e:5c:b4:b2"
  name              = "Dream Machinacho Pro Max"
  forget_on_destroy = false
  disabled          = false
}

resource "unifi_device" "usw_aggregation" {
  mac               = "1c:6a:1b:98:38:ee"
  name              = "USW Aggregation"
  forget_on_destroy = false
  disabled          = false
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
