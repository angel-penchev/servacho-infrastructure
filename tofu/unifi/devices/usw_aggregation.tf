resource "unifi_device" "usw_aggregation" {
  mac               = "1c:6a:1b:98:38:ee"
  name              = "USW Aggregation"
  forget_on_destroy = false
  disabled          = false

  # FIXME(unifi): `config_network` is populated by modelToAPIDevice but dropped by
  # buildMinimalUpdateDevice, so at v0.55.0 it is only honoured on create/adopt --
  # an update silently discards it and the apply fails with "inconsistent result
  # after apply". Declared here so the code states the intended reality; it will not
  # take effect until upstream PR #463 ships (checked 2026-09-08).
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
  # Servacho-Gosho (38:05:25:30:79:97, fixed 192.168.5.10). Moved from an inline
  # native-VLAN override to the Private Server profile on 2026-09-13; the inline
  # override also had BPDU Guard on, which the profile does not (UI-only field).
  port_override {
    index              = 1
    name               = "Servacho-Gosho"
    setting_preference = "auto"
    port_profile_id    = var.port_profile_private_servers_id
  }

  # Port State: Disabled, exactly as the controller stores it when set in the UI
  # (verified 2026-09-13 on port 9): forward "disabled" + port security on with an
  # empty allowlist + Block All tagged VLANs, no native network, manual preference.
  # Live also carries UI-only fields the provider cannot express: stp_edge_state
  # "enabled", stp_bpdu_guard_enabled true, stp_uplink false, eee_enabled false,
  # link_debounce_auto true, multicast_router_mode "NONE", sd_wan_underlay_port false.
  port_override {
    index                     = 2
    name                      = "SFP+ 2"
    forward                   = "disabled"
    port_security_enabled     = true
    port_security_mac_address = []
    tagged_vlan_mgmt          = "block_all"
    native_networkconf_id     = null
    setting_preference        = "manual"
    poe_mode                  = "auto"
    autoneg                   = true
    dot1x_ctrl                = "auto"
    lldpmed_enabled           = true
    stp_port_mode             = true
  }

  port_override {
    index                     = 3
    name                      = "SFP+ 3"
    forward                   = "disabled"
    port_security_enabled     = true
    port_security_mac_address = []
    tagged_vlan_mgmt          = "block_all"
    native_networkconf_id     = null
    setting_preference        = "manual"
    poe_mode                  = "auto"
    autoneg                   = true
    dot1x_ctrl                = "auto"
    lldpmed_enabled           = true
    stp_port_mode             = true
  }

  port_override {
    index                     = 4
    name                      = "SFP+ 4"
    forward                   = "disabled"
    port_security_enabled     = true
    port_security_mac_address = []
    tagged_vlan_mgmt          = "block_all"
    native_networkconf_id     = null
    setting_preference        = "manual"
    poe_mode                  = "auto"
    autoneg                   = true
    dot1x_ctrl                = "auto"
    lldpmed_enabled           = true
    stp_port_mode             = true
  }

  port_override {
    index                     = 5
    name                      = "SFP+ 5"
    forward                   = "disabled"
    port_security_enabled     = true
    port_security_mac_address = []
    tagged_vlan_mgmt          = "block_all"
    native_networkconf_id     = null
    setting_preference        = "manual"
    poe_mode                  = "auto"
    autoneg                   = true
    dot1x_ctrl                = "auto"
    lldpmed_enabled           = true
    stp_port_mode             = true
  }

  port_override {
    index                     = 6
    name                      = "SFP+ 6"
    forward                   = "disabled"
    port_security_enabled     = true
    port_security_mac_address = []
    tagged_vlan_mgmt          = "block_all"
    native_networkconf_id     = null
    setting_preference        = "manual"
    poe_mode                  = "auto"
    autoneg                   = true
    dot1x_ctrl                = "auto"
    lldpmed_enabled           = true
    stp_port_mode             = true
  }

  port_override {
    index                     = 7
    name                      = "SFP+ 7"
    forward                   = "disabled"
    port_security_enabled     = true
    port_security_mac_address = []
    tagged_vlan_mgmt          = "block_all"
    native_networkconf_id     = null
    setting_preference        = "manual"
    poe_mode                  = "auto"
    autoneg                   = true
    dot1x_ctrl                = "auto"
    lldpmed_enabled           = true
    stp_port_mode             = true
  }

  # SFP+ 8, uplink to the UDM.
  port_override {
    index              = 8
    name               = "UDM-Pro-Max"
    setting_preference = "auto"
    port_profile_id    = var.port_profile_unifi_devices_id
  }
}
