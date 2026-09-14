resource "unifi_device" "u7_pro_bedroom" {
  mac  = "9c:05:d6:d9:af:65"
  name = "Bedroom U7-Pro"
  # FIXME(unifi): forget_on_destroy is Optional+Computed and import sets it true; declaring
  #   the intended `false` would plan an update PUT (#463 hazard) for a provider-only flag
  #   that only matters on `tofu destroy`. Left at the imported default.
  disabled = false

  led_override = "off"

  # Management on UniFi Devices (VLAN 99), untagged. An AP must have "Network Override"
  # OFF when its uplink port is native 99: with it on, the AP tags 99, the switch answers
  # untagged, and the AP goes deaf. Override-off is stored as mgmt_network_id = Default
  # LAN (an empty value is rejected), which is also why the UI lists the AP under
  # "Default (Untagged)" although it lives on 192.168.99.x. Switches are the opposite,
  # see device_usw_*.tf.
  mgmt_network_id = unifi_network.default.id

  # FIXME(unifi): read-only in practice -- v0.55.0 drops config_network from the update
  #   PUT (upstream #463). Live matches, so the plan is a no-op; changing the address
  #   here would fail post-apply. Change it in the UI first, then mirror.
  config_network = {
    type    = "static"
    ip      = "192.168.99.5"
    netmask = "255.255.255.0"
    gateway = "192.168.99.1"
    dns1    = "192.168.99.1"
  }
}
