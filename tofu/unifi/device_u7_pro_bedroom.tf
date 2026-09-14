resource "unifi_device" "u7_pro_bedroom" {
  mac               = "9c:05:d6:d9:af:65"
  name              = "Bedroom U7-Pro"
  forget_on_destroy = false
  disabled          = false

  led_override = "off"

  # Management on UniFi Devices (VLAN 99) since 2026-09-13, UNTAGGED since Phase 4
  # (2026-09-14). For an AP "Network Override" must be OFF once its uplink port is
  # native 99: with the override on it tags 99 and the switch answers untagged, so it
  # goes deaf (verified live). Override-off is stored as mgmt_network_id = the Default
  # LAN -- the controller rejects an empty value -- which is also why the UI lists the
  # AP under "Default (Untagged)" although it lives on 192.168.99.x. Switches are the
  # opposite: they keep the override ON (see device_usw_*.tf).
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
