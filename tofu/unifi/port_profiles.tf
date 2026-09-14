# All five profiles mirror live (/rest/portconf). stp_port_mode is the Services -> STP
# toggle, not the Port Mode radio.
# Attributes left unset are optional+computed or absent on the controller.
#
# UI fields with no provider attribute (live value on all five unless noted; a
# from-scratch create lands on controller defaults):
# FIXME(unifi-ui-only): stp_edge_state -- Port Mode. UniFi Device: "disabled"
#   (Infrastructure); Host Device, Public Server, Private Server, IoT Device: "enabled" (Edge)
# FIXME(unifi-ui-only): flow_control_enabled = true        (Flow Control)
# FIXME(unifi-ui-only): precision_time_protocol_enabled = true  (PTP)
# FIXME(unifi-ui-only): qos_profile = {mode custom, no policies}  (QoS Mode: Off)
# FIXME(unifi-ui-only): stp_uplink = false                 (Services -> STP Uplink)
# FIXME(unifi-ui-only): stp_bpdu_guard_enabled -- Services -> BPDU Guard. Host Device,
#   Private Server, IoT Device: true (end-host ports); UniFi Device: false (must stay
#   off, it carries BPDUs between switches and APs); Public Server: false
# FIXME(unifi-ui-only): link_debounce_auto = true, 300 ms  (Link Debounce)
# FIXME(unifi-ui-only): eee_enabled = false                (Energy Efficient Ethernet)
# FIXME(unifi-ui-only): multicast_router_mode = "NONE"     (Multicast Router Port)

# Trunks between UniFi devices (UDM <-> switches, switches <-> APs): every VLAN, no
# 802.1X, otherwise the infrastructure could not come up before RADIUS is reachable.
# Native is UniFi Devices (VLAN 99): management is
# untagged on every trunk and a factory-reset device plugged into any of these ports
# lands on 99 with DHCP. The controller rewrites forward "all" to "customize" as soon as
# the native network is not the Default LAN; with tagged_vlan_mgmt "auto" that still
# passes every VLAN. Declared as stored so the plan is clean.
resource "unifi_port_profile" "unifi_devices" {
  name                  = "UniFi Device"
  forward               = "customize"
  native_networkconf_id = unifi_network.unifi_devices.id
  poe_mode              = "auto"
  autoneg               = true
  dot1x_ctrl            = "force_authorized"
  tagged_vlan_mgmt      = "auto"
  stp_port_mode         = true
}

# Host-facing access ports. 802.1X success -> RADIUS assigns VLAN 2 (Main); failure or
# no supplicant -> Guest. The second half is not on the profile: an unauthorized port
# with dot1x_ctrl = "auto" drops everything including DHCP, and the "Guest instead"
# behaviour is the site-wide 802.1X Fallback VLAN in Global Switch Settings.
# Native is Main because that is what an *authorized* client gets when RADIUS returns
# no VLAN.
#
# FIXME(unifi): the fallback VLAN (`global_switch.dot1x_fallback_networkconf_id` =
#   Guest) has no provider attribute at v0.55.0 and is set by hand -- see the
#   `unifi_setting_switch` block in settings.tf. Without it this profile blocks
#   every non-802.1X client.
resource "unifi_port_profile" "host_device" {
  name                  = "Host Device"
  forward               = "customize"
  native_networkconf_id = unifi_network.main.id
  poe_mode              = "auto"
  autoneg               = true
  dot1x_ctrl            = "auto"
  tagged_vlan_mgmt      = "auto"
  setting_preference    = "manual"
  stp_port_mode         = true
}

# Per-VLAN access profiles for wired servers and IoT gear: untagged on the named
# network, no 802.1X, Port Mode Edge (UI-only, see header).
resource "unifi_port_profile" "public_servers" {
  name                  = "Public Server"
  forward               = "customize"
  native_networkconf_id = unifi_network.public_servers.id
  poe_mode              = "auto"
  autoneg               = true
  dot1x_ctrl            = "force_authorized"
  tagged_vlan_mgmt      = "auto"
  setting_preference    = "manual"
  stp_port_mode         = true
}

resource "unifi_port_profile" "private_servers" {
  name                  = "Private Server"
  forward               = "customize"
  native_networkconf_id = unifi_network.private_servers.id
  poe_mode              = "auto"
  autoneg               = true
  dot1x_ctrl            = "force_authorized"
  tagged_vlan_mgmt      = "auto"
  setting_preference    = "manual"
  stp_port_mode         = true
}

resource "unifi_port_profile" "iot" {
  name                  = "IoT Device"
  forward               = "customize"
  native_networkconf_id = unifi_network.iot.id
  poe_mode              = "auto"
  autoneg               = true
  dot1x_ctrl            = "force_authorized"
  tagged_vlan_mgmt      = "auto"
  setting_preference    = "manual"
  stp_port_mode         = true
}
