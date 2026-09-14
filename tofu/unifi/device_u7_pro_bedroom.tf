resource "unifi_device" "u7_pro_bedroom" {
  mac               = "9c:05:d6:d9:af:65"
  name              = "Bedroom U7-Pro"
  forget_on_destroy = false
  disabled          = false

  led_override = "off"

  # Management on UniFi Devices (VLAN 99) since 2026-09-13.
  mgmt_network_id = unifi_network.unifi_devices.id

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
