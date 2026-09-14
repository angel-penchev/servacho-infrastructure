resource "unifi_device" "usw_pro_max_24_poe" {
  mac                = "9c:05:d6:e2:6b:1d"
  name               = "USW Pro Max 24 PoE"
  forget_on_destroy  = false
  disabled           = false
  flowctrl_enabled   = false
  jumboframe_enabled = false
  # Management moved to UniFi Devices (VLAN 99) on 2026-09-13, runbook Phase 2. This
  # attribute IS in the v0.55.0 minimal update PUT, unlike config_network below.
  mgmt_network_id = unifi_network.unifi_devices.id

  # Matches live exactly (verified 2026-09-13 after the VLAN 99 move). NOTE: at v0.55.0 the provider drops
  # config_network from the update PUT (buildMinimalUpdateDevice, upstream PR #463),
  # so this block is read-only in practice: because live already has these values the
  # plan is a no-op, but CHANGING the address here would not reach the controller and
  # the apply would fail with "inconsistent result after apply". Change the management
  # IP in the UI first, then mirror it here, until #463 ships.
  # https://github.com/ubiquiti-community/terraform-provider-unifi/pull/463
  config_network = {
    type    = "static"
    ip      = "192.168.99.2"
    netmask = "255.255.255.0"
    gateway = "192.168.99.1"
    dns1    = "192.168.99.1"
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
  # mode       = "speed"
  # brightness = 100
  # behavior   = "steady"
  # led_mode   = "etherlighting"
  #  }
  */

  # FIXME(unifi): The ubiquiti-community/unifi provider crashes on apply when attempting 
  # to disable ports due to a bug parsing the empty MAC allowlist required for the new
  # UniFi OS Port State toggles.
  # Tracking PR: https://github.com/ubiquiti-community/terraform-provider-unifi/pull/470
  # Until it is merged, we must ignore port_override changes so they can be disabled via the UI.
  lifecycle {
    ignore_changes = [port_override]
  }

  # Port overrides mirror the live controller as of 2026-09-13: every port renamed
  # to the room labels below, 9-11 disabled, 6/12/18 on their per-VLAN profiles,
  # port 25 (SFP+ 1, UDM uplink) deliberately has no override. Not reconciled by
  # apply while ignore_changes is on (upstream #430/#438, see
  # docs/unifi-manual-vs-tofu.md 14.3).

  # Profiled ports: the controller stores exactly {name, poe_mode?, setting_preference,
  # portconf_id} -- all four are declared, nothing UI-only is involved. Everything else
  # comes from the profile (see port_profiles.tf for that layer's FIXMEs).

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
    name               = "Port 6"
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

  # Ports 9-11: Port State Disabled, exactly as the controller stores it when set in
  # the UI (verified 2026-09-13 on port 9). Every attribute the provider exposes is set
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

  # jetkvm-4562a8bf464c58c8 (30:52:53:0a:09:87, fixed 192.168.5.20 in clients.tf).
  port_override {
    index              = 12
    name               = "Port 12"
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

  # jetkvm-ce4ac3437e0d935d (30:52:53:0d:1a:68, fixed 192.168.5.23).
  port_override {
    index              = 18
    name               = "Port 18"
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

  # Host Device by decision (2026-09-13); the pre-reset code had Public Servers here.
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

  # SFP+ 2 (no link as of 2026-09-13). Port 25 (SFP+ 1) is the live uplink to the UDM
  # and has no override: it runs on the switch defaults (built-in profile "All", native
  # Default (Untagged)), so nothing is stored and there is nothing to declare. Runbook
  # Phase 4 flips the UniFi Device profile's native network to VLAN 99, which port 25
  # would NOT follow -- put it on the UniFi Device profile (or move the cable to 26)
  # before that step.
  port_override {
    index              = 26
    name               = "UDM-Pro-Max"
    setting_preference = "auto"
    port_profile_id    = unifi_port_profile.unifi_devices.id
  }
}
