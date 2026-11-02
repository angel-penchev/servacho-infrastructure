resource "unifi_device" "u7_pro_living_room" {
  mac  = "9c:05:d6:d9:ad:79"
  name = "Living Room U7-Pro"
  # FIXME(unifi): forget_on_destroy is left at its default, true, on purpose. Declaring
  #   the intended `false` (a provider-only flag that only matters on `tofu destroy`)
  #   plans an update, and every unifi_device update sends a PUT, even an empty one.
  disabled = false

  led = { override = "off" }

  # Management on UniFi Devices (VLAN 99), untagged. An AP must have "Network Override"
  # OFF when its uplink port is native 99: with it on, the AP tags 99, the switch answers
  # untagged, and the AP goes deaf. Override-off is stored as mgmt_network_id = Default
  # LAN (an empty value is rejected), which is also why the UI lists the AP under
  # "Default (Untagged)" although it lives on 192.168.99.x. Switches are the opposite,
  # see device_usw_*.tf.
  mgmt_network_id = unifi_network.default.id

  # Mirrors live; changes go through the UI first. An update sends it as a whole object
  # whenever it differs from live: dns2, dnssuffix and bonding_enabled go out as "", ""
  # and false unless declared.
  config_network = {
    type    = "static"
    ip      = "192.168.99.4"
    netmask = "255.255.255.0"
    gateway = "192.168.99.1"
    dns1    = "192.168.99.1"
  }
}
