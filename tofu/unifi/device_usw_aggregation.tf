resource "unifi_device" "usw_aggregation" {
  mac  = "1c:6a:1b:98:38:ee"
  name = "USW Aggregation"
  # FIXME(unifi): forget_on_destroy is a provider-only flag, yet it is Optional+Computed
  #   and import sets it to true, so declaring the intended `false` plans an update PUT
  #   (with the #463 field-dropping hazard) just to change a value the controller never
  #   sees. Left at the imported default; it only matters on `tofu destroy`, which is
  #   never run against adopted hardware here. Upstream: make it a plain Optional with
  #   a default, or exclude it from the update diff.
  disabled = false

  # Management on UniFi Devices (VLAN 99) since 2026-09-13. A switch keeps "Network
  # Override" ON even though the trunks are native 99 since Phase 4 (2026-09-14): its
  # CPU sits in VLAN 99 and the uplink's PVID strips the tag, so the wire is untagged.
  # Override OFF would put the CPU in VLAN 1 and send management *tagged 1* out a
  # native-99 uplink -- the switch goes dark (happened live, fixed by a cable move).
  # APs are the opposite, see device_u7_pro_*.tf.
  mgmt_network_id = unifi_network.unifi_devices.id

  # FIXME(unifi): read-only in practice -- v0.55.0 drops config_network from the update
  #   PUT (upstream #463). Live matches, so the plan is a no-op; changing the address
  #   here would fail post-apply. Change it in the UI first, then mirror.
  config_network = {
    type    = "static"
    ip      = "192.168.99.3"
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

  # Port overrides read back 2026-09-13. Profiled ports store exactly {name, poe_mode?,
  # setting_preference, portconf_id}; everything else comes from the profile
  # (port_profiles.tf).

  # Servacho-Gosho (38:05:25:30:79:97, fixed 192.168.5.10).
  # FIXME(unifi-ui-only): BPDU Guard is on via the Private Server profile; the provider
  #   cannot set it on either layer.
  port_override {
    index              = 1
    name               = "Servacho-Gosho"
    setting_preference = "auto"
    port_profile_id    = unifi_port_profile.private_servers.id
  }

  # Ports 2-7: Port State Disabled, in the switch's shape (read back 2026-09-13).
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
    index                          = 2
    name                           = "SFP+ 2 (Disabled)"
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
    index                          = 3
    name                           = "SFP+ 3 (Disabled)"
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
    index                          = 4
    name                           = "SFP+ 4 (Disabled)"
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
    index                          = 5
    name                           = "SFP+ 5 (Disabled)"
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
    index                          = 6
    name                           = "SFP+ 6 (Disabled)"
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
    index                          = 7
    name                           = "SFP+ 7 (Disabled)"
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

  # SFP+ 8, uplink to the UDM.
  port_override {
    index              = 8
    name               = "UDM-Pro-Max"
    setting_preference = "auto"
    port_profile_id    = unifi_port_profile.unifi_devices.id
  }
}
