resource "unifi_device" "udm_pro_max" {
  mac  = "28:70:4e:5c:b4:b2"
  name = "UDM StKr"
  # forget_on_destroy is left at the provider default (true, as imported). Declaring
  # false planned an update PUT on every device for a flag that only matters on a
  # `tofu destroy`, which is never run against adopted hardware here.
  disabled = false

  # FIXME(unifi): port_override is ignored until upstream #470 (crash on the empty MAC
  #   allowlist of a disabled port) and #430/#438 (whole-array replacement strips
  #   undeclared ports) land. The blocks below document live; apply does not reconcile them.
  lifecycle {
    ignore_changes = [port_override]
  }

  # Port overrides read back 2026-09-13. Profiled ports store exactly {name, poe_mode?,
  # setting_preference, portconf_id}; everything else comes from the profile
  # (port_profiles.tf).
  #
  # FIXME(unifi-ui-only): ports 1 (WAN2) and 9 (WAN1) have no override. WAN-to-port
  #   binding is UniFi OS Internet configuration, outside port_overrides; the provider
  #   has no attribute for it. The WANs themselves are in wans.tf.

  # Ports 2-8: Port State Disabled, in the gateway's shape (smaller than the switches':
  # setting_preference "auto", no dot1x/STP/PoE keys). Every exposed attribute is set.
  # FIXME(unifi-ui-only): sd_wan_underlay_port = false     (SD-WAN Underlay Port off)
  # Port 2 was briefly "Console" (Main access for the safety-net laptop) during runbook
  # Phase 4 on 2026-09-14 and disabled again the same day once the laptop was unplugged.
  port_override {
    index                          = 2
    name                           = "Port 2 (Disabled)"
    forward                        = "disabled"
    port_security_enabled          = true
    port_security_mac_address      = []
    tagged_vlan_mgmt               = "block_all"
    native_networkconf_id          = null
    voice_networkconf_id           = null
    setting_preference             = "auto"
    autoneg                        = true
    isolation                      = false
    egress_rate_limit_kbps_enabled = false
    port_keepalive_enabled         = false
  }

  port_override {
    index                          = 3
    name                           = "Port 3 (Disabled)"
    forward                        = "disabled"
    port_security_enabled          = true
    port_security_mac_address      = []
    tagged_vlan_mgmt               = "block_all"
    native_networkconf_id          = null
    voice_networkconf_id           = null
    setting_preference             = "auto"
    autoneg                        = true
    isolation                      = false
    egress_rate_limit_kbps_enabled = false
    port_keepalive_enabled         = false
  }

  port_override {
    index                          = 4
    name                           = "Port 4 (Disabled)"
    forward                        = "disabled"
    port_security_enabled          = true
    port_security_mac_address      = []
    tagged_vlan_mgmt               = "block_all"
    native_networkconf_id          = null
    voice_networkconf_id           = null
    setting_preference             = "auto"
    autoneg                        = true
    isolation                      = false
    egress_rate_limit_kbps_enabled = false
    port_keepalive_enabled         = false
  }

  port_override {
    index                          = 5
    name                           = "Port 5 (Disabled)"
    forward                        = "disabled"
    port_security_enabled          = true
    port_security_mac_address      = []
    tagged_vlan_mgmt               = "block_all"
    native_networkconf_id          = null
    voice_networkconf_id           = null
    setting_preference             = "auto"
    autoneg                        = true
    isolation                      = false
    egress_rate_limit_kbps_enabled = false
    port_keepalive_enabled         = false
  }

  port_override {
    index                          = 6
    name                           = "Port 6 (Disabled)"
    forward                        = "disabled"
    port_security_enabled          = true
    port_security_mac_address      = []
    tagged_vlan_mgmt               = "block_all"
    native_networkconf_id          = null
    voice_networkconf_id           = null
    setting_preference             = "auto"
    autoneg                        = true
    isolation                      = false
    egress_rate_limit_kbps_enabled = false
    port_keepalive_enabled         = false
  }

  port_override {
    index                          = 7
    name                           = "Port 7 (Disabled)"
    forward                        = "disabled"
    port_security_enabled          = true
    port_security_mac_address      = []
    tagged_vlan_mgmt               = "block_all"
    native_networkconf_id          = null
    voice_networkconf_id           = null
    setting_preference             = "auto"
    autoneg                        = true
    isolation                      = false
    egress_rate_limit_kbps_enabled = false
    port_keepalive_enabled         = false
  }

  port_override {
    index                          = 8
    name                           = "Port 8 (Disabled)"
    forward                        = "disabled"
    port_security_enabled          = true
    port_security_mac_address      = []
    tagged_vlan_mgmt               = "block_all"
    native_networkconf_id          = null
    voice_networkconf_id           = null
    setting_preference             = "auto"
    autoneg                        = true
    isolation                      = false
    egress_rate_limit_kbps_enabled = false
    port_keepalive_enabled         = false
  }

  # SFP+ 1: 10 GbE uplink to the USW Pro Max 24 PoE.
  port_override {
    index              = 10
    name               = "USW-Pro-Max-24-PoE"
    setting_preference = "auto"
    port_profile_id    = unifi_port_profile.unifi_devices.id
  }

  # SFP+ 2: 10 GbE uplink to the USW Aggregation.
  port_override {
    index              = 11
    name               = "USW-Aggregation"
    setting_preference = "auto"
    port_profile_id    = unifi_port_profile.unifi_devices.id
  }
}
