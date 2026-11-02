resource "unifi_device" "usw_aggregation" {
  mac  = "1c:6a:1b:98:38:ee"
  name = "USW Aggregation"
  # FIXME(unifi): forget_on_destroy is left at its default, true, on purpose. Declaring
  #   the intended `false` (a provider-only flag that only matters on `tofu destroy`)
  #   plans an update, and every unifi_device update sends a PUT, even an empty one.
  disabled = false

  # Management on UniFi Devices (VLAN 99). A switch keeps "Network Override" ON although
  # the trunks are native 99: its CPU sits in VLAN 99 and the uplink's PVID strips the
  # tag. Override OFF would put the CPU in VLAN 1 and send management *tagged 1* out a
  # native-99 uplink -- the switch goes dark. APs are the opposite, see device_u7_pro_*.tf.
  mgmt_network_id = unifi_network.unifi_devices.id

  # Mirrors live; changes go through the UI first. An update sends it as a whole object
  # whenever it differs from live: dns2, dnssuffix and bonding_enabled go out as "", ""
  # and false unless declared.
  config_network = {
    type    = "static"
    ip      = "192.168.99.3"
    netmask = "255.255.255.0"
    gateway = "192.168.99.1"
    dns1    = "192.168.99.1"
  }

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

  # Servacho-Gosho (38:05:25:30:79:97, fixed 192.168.5.10).
  # FIXME(unifi-ui-only): BPDU Guard is on via the Private Server profile; the provider
  #   cannot set it on either layer, and any provider write to the profile turns it off
  #   (port_profiles.tf).
  port_override {
    index              = 1
    name               = "Servacho-Gosho"
    setting_preference = "auto"
    port_profile_id    = unifi_port_profile.private_servers.id
  }

  # Ports 2-7: Port State Disabled, in the switch's shape; stp_edge_state "enabled" is
  # Port Mode: Edge. Every exposed attribute is set; the live override also carries
  # these UI-only keys:
  # FIXME(unifi-ui-only): stp_bpdu_guard_enabled = true    (Services -> BPDU Guard)
  # FIXME(unifi-ui-only): stp_uplink = false               (Services -> STP Uplink)
  # FIXME(unifi-ui-only): eee_enabled = false              (Energy Efficient Ethernet)
  # FIXME(unifi-ui-only): link_debounce_auto = true        (Link Debounce: Auto, 300 ms)
  # FIXME(unifi-ui-only): multicast_router_mode = "NONE"   (Multicast Router Port off)
  # FIXME(unifi-ui-only): sd_wan_underlay_port = false     (SD-WAN Underlay Port off)
  port_override {
    index                  = 2
    name                   = "SFP+ 2 (Disabled)"
    forward                = "disabled"
    port_security          = { enabled = true }
    tagged_vlan_mgmt       = "block_all"
    native_networkconf_id  = null
    voice_networkconf_id   = null
    setting_preference     = "manual"
    poe_mode               = "auto"
    autoneg                = true
    dot1x                  = { ctrl = "auto", idle_timeout = "5m0s" }
    lldpmed                = { enabled = true }
    stp_port_mode          = true
    stp_edge_state         = "enabled"
    isolation              = false
    egress_rate_limit      = { enabled = false }
    port_keepalive_enabled = false
  }

  port_override {
    index                  = 3
    name                   = "SFP+ 3 (Disabled)"
    forward                = "disabled"
    port_security          = { enabled = true }
    tagged_vlan_mgmt       = "block_all"
    native_networkconf_id  = null
    voice_networkconf_id   = null
    setting_preference     = "manual"
    poe_mode               = "auto"
    autoneg                = true
    dot1x                  = { ctrl = "auto", idle_timeout = "5m0s" }
    lldpmed                = { enabled = true }
    stp_port_mode          = true
    stp_edge_state         = "enabled"
    isolation              = false
    egress_rate_limit      = { enabled = false }
    port_keepalive_enabled = false
  }

  port_override {
    index                  = 4
    name                   = "SFP+ 4 (Disabled)"
    forward                = "disabled"
    port_security          = { enabled = true }
    tagged_vlan_mgmt       = "block_all"
    native_networkconf_id  = null
    voice_networkconf_id   = null
    setting_preference     = "manual"
    poe_mode               = "auto"
    autoneg                = true
    dot1x                  = { ctrl = "auto", idle_timeout = "5m0s" }
    lldpmed                = { enabled = true }
    stp_port_mode          = true
    stp_edge_state         = "enabled"
    isolation              = false
    egress_rate_limit      = { enabled = false }
    port_keepalive_enabled = false
  }

  port_override {
    index                  = 5
    name                   = "SFP+ 5 (Disabled)"
    forward                = "disabled"
    port_security          = { enabled = true }
    tagged_vlan_mgmt       = "block_all"
    native_networkconf_id  = null
    voice_networkconf_id   = null
    setting_preference     = "manual"
    poe_mode               = "auto"
    autoneg                = true
    dot1x                  = { ctrl = "auto", idle_timeout = "5m0s" }
    lldpmed                = { enabled = true }
    stp_port_mode          = true
    stp_edge_state         = "enabled"
    isolation              = false
    egress_rate_limit      = { enabled = false }
    port_keepalive_enabled = false
  }

  port_override {
    index                  = 6
    name                   = "SFP+ 6 (Disabled)"
    forward                = "disabled"
    port_security          = { enabled = true }
    tagged_vlan_mgmt       = "block_all"
    native_networkconf_id  = null
    voice_networkconf_id   = null
    setting_preference     = "manual"
    poe_mode               = "auto"
    autoneg                = true
    dot1x                  = { ctrl = "auto", idle_timeout = "5m0s" }
    lldpmed                = { enabled = true }
    stp_port_mode          = true
    stp_edge_state         = "enabled"
    isolation              = false
    egress_rate_limit      = { enabled = false }
    port_keepalive_enabled = false
  }

  port_override {
    index                  = 7
    name                   = "SFP+ 7 (Disabled)"
    forward                = "disabled"
    port_security          = { enabled = true }
    tagged_vlan_mgmt       = "block_all"
    native_networkconf_id  = null
    voice_networkconf_id   = null
    setting_preference     = "manual"
    poe_mode               = "auto"
    autoneg                = true
    dot1x                  = { ctrl = "auto", idle_timeout = "5m0s" }
    lldpmed                = { enabled = true }
    stp_port_mode          = true
    stp_edge_state         = "enabled"
    isolation              = false
    egress_rate_limit      = { enabled = false }
    port_keepalive_enabled = false
  }

  # SFP+ 8, uplink to the UDM.
  port_override {
    index              = 8
    name               = "UDM-Pro-Max"
    setting_preference = "auto"
    port_profile_id    = unifi_port_profile.unifi_devices.id
  }
}
