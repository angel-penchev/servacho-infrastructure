resource "unifi_device" "udm_pro_max" {
  mac               = "28:70:4e:5c:b4:b2"
  name              = "UDM StKr"
  forget_on_destroy = false
  disabled          = false

  # FIXME(unifi): The ubiquiti-community/unifi provider crashes on apply when attempting 
  # to disable ports due to a bug parsing the empty MAC allowlist required for the new
  # UniFi OS Port State toggles.
  # Tracking PR: https://github.com/ubiquiti-community/terraform-provider-unifi/pull/470
  # Until it is merged, we must ignore port_override changes so they can be disabled via the UI.
  lifecycle {
    ignore_changes = [port_override]
  }

  # Port overrides mirror the live controller as of 2026-09-13: 2-8 disabled, the two
  # SFP+ uplinks on the UniFi Device profile. Ports 1 (WAN2) and 9 (WAN1) carry NO
  # override: WAN-to-port binding is UniFi OS Internet configuration, not a switch-port
  # override with a WAN native network -- the pre-reset code modelled it that way and
  # it never corresponded to anything the controller stores. Not reconciled by apply
  # while ignore_changes is on (upstream #430/#438, see docs/unifi-manual-vs-tofu.md 14.3).
  # Ports 2-8: Port State Disabled, exactly as the gateway stores it when set in the
  # UI (verified 2026-09-13 on port 2): forward "disabled" + port security on with an
  # empty allowlist + Block All tagged VLANs, no native network. Unlike the switches
  # the gateway keeps setting_preference "auto" and carries no dot1x/STP fields. Live
  # also has UI-only keys the provider lacks: sd_wan_underlay_port false, plus
  # isolation/egress_rate_limit/port_keepalive false (computed here).


  # Profiled ports: the controller stores exactly {name, poe_mode?, setting_preference,
  # portconf_id} -- all four are declared, nothing UI-only is involved. Everything else
  # comes from the profile (see ../core/port_profiles.tf for that layer's FIXMEs).

  # FIXME(unifi-ui-only): ports 1 (WAN2) and 9 (WAN1) have no override. Which physical
  #   port carries which WAN is UniFi OS Internet configuration, stored outside the
  #   Network application's port_overrides; the provider has no attribute for it. The
  #   WANs themselves are ../core/wans.tf.

  # Ports 2-8: Port State Disabled, exactly as the gateway stores it when set in the
  # UI (verified 2026-09-13 on port 2). Unlike the switches the gateway keeps
  # setting_preference "auto" and carries no dot1x/STP/PoE keys. Every attribute the
  # provider exposes is set explicitly below. UI-only key without a provider attribute:
  # FIXME(unifi-ui-only): sd_wan_underlay_port = false     (SD-WAN Underlay Port off)
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

  # SFP+ 1: 10 GbE uplink to the USW Pro Max 24 PoE. The pre-reset code had the
  # Private Servers profile here, which was wrong for an inter-switch link.
  port_override {
    index              = 10
    name               = "SFP+ 1"
    setting_preference = "auto"
    port_profile_id    = var.port_profile_unifi_devices_id
  }

  # SFP+ 2: 10 GbE uplink to the USW Aggregation.
  port_override {
    index              = 11
    name               = "USW-Aggregation"
    setting_preference = "auto"
    port_profile_id    = var.port_profile_unifi_devices_id
  }
}
