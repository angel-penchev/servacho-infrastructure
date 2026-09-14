resource "unifi_device" "usw_pro_max_24_poe" {
  mac  = "9c:05:d6:e2:6b:1d"
  name = "USW Pro Max 24 PoE"
  # FIXME(unifi): forget_on_destroy is Optional+Computed and import sets it true; declaring
  #   the intended `false` would plan an update PUT (#463 hazard) for a provider-only flag
  #   that only matters on `tofu destroy`. Left at the imported default.
  disabled = false
  # Management on UniFi Devices (VLAN 99). A switch keeps "Network Override" ON although
  # the trunks are native 99: its CPU sits in VLAN 99 and the uplink's PVID strips the
  # tag. Override OFF would put the CPU in VLAN 1 and send management *tagged 1* out a
  # native-99 uplink -- the switch goes dark. APs are the opposite, see device_u7_pro_*.tf.
  mgmt_network_id = unifi_network.unifi_devices.id

  # FIXME(unifi): read-only in practice -- v0.55.0 drops config_network from the update
  #   PUT (upstream #463). Live matches, so the plan is a no-op; changing the address
  #   here would fail post-apply. Change it in the UI first, then mirror.
  config_network = {
    type    = "static"
    ip      = "192.168.99.2"
    netmask = "255.255.255.0"
    gateway = "192.168.99.1"
    dns1    = "192.168.99.1"
  }

  # FIXME(unifi): port_override is ignored until upstream #470 (crash on the empty MAC
  #   allowlist of a disabled port) and #430/#438 (whole-array replacement strips
  #   undeclared ports) land. The blocks below document live; apply does not reconcile them.
  lifecycle {
    ignore_changes = [port_override]
  }

  # Profiled ports store exactly {name, poe_mode?, setting_preference, portconf_id};
  # everything else comes from the profile (port_profiles.tf).

  port_override {
    index              = 1
    name               = "LR-01"
    poe_mode           = "auto"
    setting_preference = "auto"
    port_profile_id    = unifi_port_profile.host_device.id
  }

  port_override {
    index              = 2
    name               = "LR-02"
    poe_mode           = "auto"
    setting_preference = "auto"
    port_profile_id    = unifi_port_profile.host_device.id
  }

  port_override {
    index              = 3
    name               = "LR-03"
    poe_mode           = "auto"
    setting_preference = "auto"
    port_profile_id    = unifi_port_profile.host_device.id
  }

  port_override {
    index              = 4
    name               = "LR-04"
    poe_mode           = "auto"
    setting_preference = "auto"
    port_profile_id    = unifi_port_profile.host_device.id
  }

  port_override {
    index              = 5
    name               = "LR-05"
    poe_mode           = "auto"
    setting_preference = "auto"
    port_profile_id    = unifi_port_profile.host_device.id
  }

  # Living Room TV (b0:b3:69:41:2c:9b, fixed 192.168.6.10).
  port_override {
    index              = 6
    name               = "LR-06"
    poe_mode           = "auto"
    setting_preference = "manual"
    port_profile_id    = unifi_port_profile.iot.id
  }

  port_override {
    index              = 7
    name               = "Balc-01"
    poe_mode           = "auto"
    setting_preference = "auto"
    port_profile_id    = unifi_port_profile.host_device.id
  }

  port_override {
    index              = 8
    name               = "Balc-02"
    poe_mode           = "auto"
    setting_preference = "auto"
    port_profile_id    = unifi_port_profile.host_device.id
  }

  # Ports 9-11: Port State Disabled, in the switch's shape.
  # Every exposed attribute is set; the live override also carries these UI-only keys:
  # FIXME(unifi-ui-only): stp_edge_state = "enabled"       (Port Mode: Edge)
  # FIXME(unifi-ui-only): stp_bpdu_guard_enabled = true    (Services -> BPDU Guard)
  # FIXME(unifi-ui-only): stp_uplink = false               (Services -> STP Uplink)
  # FIXME(unifi-ui-only): eee_enabled = false              (Energy Efficient Ethernet)
  # FIXME(unifi-ui-only): link_debounce_auto = true        (Link Debounce: Auto, 300 ms)
  # FIXME(unifi-ui-only): multicast_router_mode = "NONE"   (Multicast Router Port off)
  # FIXME(unifi-ui-only): sd_wan_underlay_port = false     (SD-WAN Underlay Port off)
  # FIXME(unifi-ui-only): dot1x_idle_timeout = 300 s -- exposed, but as a Go duration
  #   string ("5m0s"); left unset because 300 s is the provider default anyway.
  port_override {
    index                          = 9
    name                           = "Port 9 (Disabled)"
    forward                        = "disabled"
    port_security_enabled          = true
    port_security_mac_address      = []
    tagged_vlan_mgmt               = "block_all"
    native_networkconf_id          = null
    voice_networkconf_id           = null
    setting_preference             = "manual"
    poe_mode                       = "auto"
    autoneg                        = true
    dot1x_ctrl                     = "auto"
    lldpmed_enabled                = true
    stp_port_mode                  = true
    isolation                      = false
    egress_rate_limit_kbps_enabled = false
    port_keepalive_enabled         = false
  }

  port_override {
    index                          = 10
    name                           = "Port 10 (Disabled)"
    forward                        = "disabled"
    port_security_enabled          = true
    port_security_mac_address      = []
    tagged_vlan_mgmt               = "block_all"
    native_networkconf_id          = null
    voice_networkconf_id           = null
    setting_preference             = "manual"
    poe_mode                       = "auto"
    autoneg                        = true
    dot1x_ctrl                     = "auto"
    lldpmed_enabled                = true
    stp_port_mode                  = true
    isolation                      = false
    egress_rate_limit_kbps_enabled = false
    port_keepalive_enabled         = false
  }

  port_override {
    index                          = 11
    name                           = "Port 11 (Disabled)"
    forward                        = "disabled"
    port_security_enabled          = true
    port_security_mac_address      = []
    tagged_vlan_mgmt               = "block_all"
    native_networkconf_id          = null
    voice_networkconf_id           = null
    setting_preference             = "manual"
    poe_mode                       = "auto"
    autoneg                        = true
    dot1x_ctrl                     = "auto"
    lldpmed_enabled                = true
    stp_port_mode                  = true
    isolation                      = false
    egress_rate_limit_kbps_enabled = false
    port_keepalive_enabled         = false
  }

  # 30:52:53:0a:09:87, fixed 192.168.5.20.
  port_override {
    index              = 12
    name               = "JetKVM-Servacho-Gosho"
    poe_mode           = "auto"
    setting_preference = "manual"
    port_profile_id    = unifi_port_profile.private_servers.id
  }

  port_override {
    index              = 13
    name               = "K-01"
    poe_mode           = "auto"
    setting_preference = "auto"
    port_profile_id    = unifi_port_profile.host_device.id
  }

  port_override {
    index              = 14
    name               = "K-02"
    poe_mode           = "auto"
    setting_preference = "auto"
    port_profile_id    = unifi_port_profile.host_device.id
  }

  port_override {
    index              = 15
    name               = "BR-07"
    poe_mode           = "auto"
    setting_preference = "auto"
    port_profile_id    = unifi_port_profile.host_device.id
  }

  port_override {
    index              = 16
    name               = "BR-08"
    poe_mode           = "auto"
    setting_preference = "auto"
    port_profile_id    = unifi_port_profile.host_device.id
  }

  port_override {
    index              = 17
    name               = "BR-01"
    poe_mode           = "auto"
    setting_preference = "auto"
    port_profile_id    = unifi_port_profile.host_device.id
  }

  # 30:52:53:0d:1a:68, fixed 192.168.5.23.
  port_override {
    index              = 18
    name               = "JetKVM-Michelangelo"
    poe_mode           = "auto"
    setting_preference = "manual"
    port_profile_id    = unifi_port_profile.private_servers.id
  }

  port_override {
    index              = 19
    name               = "BR-03"
    poe_mode           = "auto"
    setting_preference = "auto"
    port_profile_id    = unifi_port_profile.host_device.id
  }

  port_override {
    index              = 20
    name               = "BR-04"
    poe_mode           = "auto"
    setting_preference = "auto"
    port_profile_id    = unifi_port_profile.host_device.id
  }

  port_override {
    index              = 21
    name               = "BR-05"
    poe_mode           = "auto"
    setting_preference = "auto"
    port_profile_id    = unifi_port_profile.host_device.id
  }

  port_override {
    index              = 22
    name               = "BR-06"
    poe_mode           = "auto"
    setting_preference = "auto"
    port_profile_id    = unifi_port_profile.host_device.id
  }

  # Living Room U7-Pro uplink.
  port_override {
    index              = 23
    name               = "LR-WiFi"
    setting_preference = "auto"
    port_profile_id    = unifi_port_profile.unifi_devices.id
  }

  # Bedroom U7-Pro uplink.
  port_override {
    index              = 24
    name               = "BR-WiFi"
    setting_preference = "auto"
    port_profile_id    = unifi_port_profile.unifi_devices.id
  }

  # SFP+ 1: unused, Port State Disabled. Same shape and UI-only keys as ports 9-11.
  port_override {
    index                          = 25
    name                           = "SFP+ 1 (Disabled)"
    forward                        = "disabled"
    port_security_enabled          = true
    port_security_mac_address      = []
    tagged_vlan_mgmt               = "block_all"
    native_networkconf_id          = null
    voice_networkconf_id           = null
    setting_preference             = "manual"
    poe_mode                       = "auto"
    autoneg                        = true
    dot1x_ctrl                     = "auto"
    lldpmed_enabled                = true
    stp_port_mode                  = true
    isolation                      = false
    egress_rate_limit_kbps_enabled = false
    port_keepalive_enabled         = false
  }

  # SFP+ 2: 10 GbE uplink to UDM port 10.
  port_override {
    index              = 26
    name               = "UDM-Pro-Max"
    setting_preference = "auto"
    port_profile_id    = unifi_port_profile.unifi_devices.id
  }
}
