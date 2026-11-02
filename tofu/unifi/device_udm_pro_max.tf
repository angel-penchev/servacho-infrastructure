resource "unifi_device" "udm_pro_max" {
  mac  = "28:70:4e:5c:b4:b2"
  name = "UDM StKr"
  # FIXME(unifi): forget_on_destroy is left at its default, true, on purpose. Declaring
  #   the intended `false` (a provider-only flag that only matters on `tofu destroy`)
  #   plans an update, and every unifi_device update sends a PUT, even an empty one.
  disabled = false

  # FIXME(unifi): import and refresh never put port_override in state, so without this
  #   ignore the first plan adds every block unchecked, and the apply PUTs the whole
  #   array unless each entry already equals live. unifi_device_port (import per port)
  #   is the way out once CI runs OpenTofu >= 1.12 or upstream sets the identity in its
  #   Update; until then every in-place update of it fails after the PUT. The blocks
  #   below document live; apply does not reconcile them.
  lifecycle {
    ignore_changes = [port_override]
  }

  # Profiled ports store exactly {name, poe_mode?, setting_preference, portconf_id};
  # everything else comes from the profile (port_profiles.tf).
  #
  # FIXME(unifi-ui-only): ports 1 (WAN2) and 9 (WAN1) have no override. The WAN-to-port
  #   binding (Settings -> Internet) sits outside port_overrides, probably in the
  #   device's ethernet_overrides that go-unifi models (unchecked on this UDM); the
  #   provider neither exposes nor sends that key. The WANs themselves are in wans.tf.

  # Ports 2-8: Port State Disabled, in the gateway's shape (smaller than the switches':
  # setting_preference "auto", no dot1x/STP/PoE keys). Every exposed attribute is set.
  # FIXME(unifi-ui-only): sd_wan_underlay_port = false     (SD-WAN Underlay Port off)
  port_override {
    index                  = 2
    name                   = "Port 2 (Disabled)"
    forward                = "disabled"
    port_security          = { enabled = true }
    tagged_vlan_mgmt       = "block_all"
    native_networkconf_id  = null
    voice_networkconf_id   = null
    setting_preference     = "auto"
    autoneg                = true
    isolation              = false
    egress_rate_limit      = { enabled = false }
    port_keepalive_enabled = false
  }

  port_override {
    index                  = 3
    name                   = "Port 3 (Disabled)"
    forward                = "disabled"
    port_security          = { enabled = true }
    tagged_vlan_mgmt       = "block_all"
    native_networkconf_id  = null
    voice_networkconf_id   = null
    setting_preference     = "auto"
    autoneg                = true
    isolation              = false
    egress_rate_limit      = { enabled = false }
    port_keepalive_enabled = false
  }

  port_override {
    index                  = 4
    name                   = "Port 4 (Disabled)"
    forward                = "disabled"
    port_security          = { enabled = true }
    tagged_vlan_mgmt       = "block_all"
    native_networkconf_id  = null
    voice_networkconf_id   = null
    setting_preference     = "auto"
    autoneg                = true
    isolation              = false
    egress_rate_limit      = { enabled = false }
    port_keepalive_enabled = false
  }

  port_override {
    index                  = 5
    name                   = "Port 5 (Disabled)"
    forward                = "disabled"
    port_security          = { enabled = true }
    tagged_vlan_mgmt       = "block_all"
    native_networkconf_id  = null
    voice_networkconf_id   = null
    setting_preference     = "auto"
    autoneg                = true
    isolation              = false
    egress_rate_limit      = { enabled = false }
    port_keepalive_enabled = false
  }

  port_override {
    index                  = 6
    name                   = "Port 6 (Disabled)"
    forward                = "disabled"
    port_security          = { enabled = true }
    tagged_vlan_mgmt       = "block_all"
    native_networkconf_id  = null
    voice_networkconf_id   = null
    setting_preference     = "auto"
    autoneg                = true
    isolation              = false
    egress_rate_limit      = { enabled = false }
    port_keepalive_enabled = false
  }

  port_override {
    index                  = 7
    name                   = "Port 7 (Disabled)"
    forward                = "disabled"
    port_security          = { enabled = true }
    tagged_vlan_mgmt       = "block_all"
    native_networkconf_id  = null
    voice_networkconf_id   = null
    setting_preference     = "auto"
    autoneg                = true
    isolation              = false
    egress_rate_limit      = { enabled = false }
    port_keepalive_enabled = false
  }

  port_override {
    index                  = 8
    name                   = "Port 8 (Disabled)"
    forward                = "disabled"
    port_security          = { enabled = true }
    tagged_vlan_mgmt       = "block_all"
    native_networkconf_id  = null
    voice_networkconf_id   = null
    setting_preference     = "auto"
    autoneg                = true
    isolation              = false
    egress_rate_limit      = { enabled = false }
    port_keepalive_enabled = false
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
