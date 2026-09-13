resource "unifi_device" "usw_aggregation" {
  mac               = "1c:6a:1b:98:38:ee"
  name              = "USW Aggregation"
  forget_on_destroy = false
  disabled          = false

  # Matches live exactly (verified 2026-09-13). NOTE: at v0.55.0 the provider drops
  # config_network from the update PUT (buildMinimalUpdateDevice, upstream PR #463),
  # so this block is read-only in practice: because live already has these values the
  # plan is a no-op, but CHANGING the address here would not reach the controller and
  # the apply would fail with "inconsistent result after apply". Change the management
  # IP in the UI first, then mirror it here, until #463 ships.
  # https://github.com/ubiquiti-community/terraform-provider-unifi/pull/463
  config_network = {
    type    = "static"
    ip      = "192.168.1.3"
    netmask = "255.255.255.0"
    gateway = "192.168.1.1"
    dns1    = "192.168.1.1"
  }

  # FIXME(unifi): The ubiquiti-community/unifi provider crashes on apply when attempting 
  # to disable ports due to a bug parsing the empty MAC allowlist required for the new
  # UniFi OS Port State toggles.
  # Tracking PR: https://github.com/ubiquiti-community/terraform-provider-unifi/pull/470
  # Until it is merged, we must ignore port_override changes so they can be disabled via the UI.
  lifecycle {
    ignore_changes = [port_override]
  }

  # Port overrides mirror the live controller as of 2026-09-13: port 1 on the
  # Private Server profile, 2-7 disabled, 8 renamed. Not reconciled by apply while
  # ignore_changes is on (upstream #430/#438, see docs/unifi-manual-vs-tofu.md 14.3).

  # Profiled ports: the controller stores exactly {name, poe_mode?, setting_preference,
  # portconf_id} -- all four are declared, nothing UI-only is involved. Everything else
  # comes from the profile (see ../core/port_profiles.tf for that layer's FIXMEs).

  # Servacho-Gosho (38:05:25:30:79:97, fixed 192.168.5.10). Moved from an inline
  # native-VLAN override to the Private Server profile on 2026-09-13.
  # FIXME(unifi-ui-only): BPDU Guard comes from the profile now (Private Server, on
  #   since 2026-09-13) and the provider cannot set it on either layer.
  port_override {
    index              = 1
    name               = "Servacho-Gosho"
    setting_preference = "auto"
    port_profile_id    = var.port_profile_private_servers_id
  }

  # Ports 2-7: Port State Disabled, exactly as the controller stores it when set in
  # the UI (verified 2026-09-13 on Pro Max port 9, copied here). Every attribute the provider exposes is set
  # explicitly below to the live value. The live override also carries these UI-only
  # keys, which unifi_device.port_override has no attribute for -- a from-scratch
  # apply would leave them at controller defaults:
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
    name                           = "SFP+ 2"
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
    name                           = "SFP+ 3"
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
    name                           = "SFP+ 4"
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
    name                           = "SFP+ 5"
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
    name                           = "SFP+ 6"
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
    name                           = "SFP+ 7"
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
    port_profile_id    = var.port_profile_unifi_devices_id
  }
}
