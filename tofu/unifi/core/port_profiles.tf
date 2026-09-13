# ----------------------------------------------------------------------------
# Port profiles
#
# Five profiles exist on the controller after the 2026-09 rebuild and all five are
# declared here. The three per-VLAN profiles were recreated by hand on 2026-09-13
# and this file was aligned to them (names, setting_preference, stp_port_mode).
#
# Audit 2026-09-13: every field of the UI profile editor was mapped against
# /rest/portconf and the v0.55.0 unifi_port_profile schema. Everything the provider
# can express matches live. Attributes left unset here are optional+computed (the
# provider adopts the controller value) or absent on the controller.
#
# UI fields with NO provider attribute -- live value on all five profiles unless
# noted; managed in the UI only, so a from-scratch create lands on controller
# defaults, not on these:
#   Port Mode (Infrastructure/Edge)  stp_edge_state   UniFi Device: disabled (Infrastructure)
#                                                     the other four: enabled (Edge)
#   Flow Control                     flow_control_enabled = true
#   Precision Time Protocol          precision_time_protocol_enabled = true
#   QoS Mode                         qos_profile = {mode custom, no policies}  (UI: Off)
#   STP Uplink / BPDU Guard          stp_uplink = false / stp_bpdu_guard_enabled = false
#   Link Debounce                    link_debounce_auto = true (300 ms)
#   Energy Efficient Ethernet        eee_enabled = false
#   Multicast Router Port            multicast_router_mode = "NONE"
#
# NOTE stp_port_mode is the Services -> STP toggle (true on all five, including
# UniFi Device), NOT the Port Mode: Edge radio. Earlier comments here and in the
# docs had that backwards.
# ----------------------------------------------------------------------------

# Uplinks between UniFi devices themselves (UDM <-> switches, switches <-> APs).
# Trunks every VLAN and never runs 802.1X, otherwise the infrastructure could not
# come up before RADIUS is reachable.
resource "unifi_port_profile" "unifi_devices" {
  name                  = "UniFi Device"
  forward               = "all"
  native_networkconf_id = unifi_network.default.id
  poe_mode              = "auto"
  autoneg               = true
  dot1x_ctrl            = "force_authorized"
  tagged_vlan_mgmt      = "auto"
  stp_port_mode         = true
}

# Host-facing access ports on the USW Pro Max 24 PoE.
#
# Intended behaviour:
#   - client passes 802.1X  -> RADIUS returns Tunnel-Private-Group-ID 2 -> Main (VLAN 2)
#   - client fails / has no supplicant -> Guest (VLAN 3)
#
# The second half is NOT expressible here. A port with dot1x_ctrl = "auto" stays
# unauthorized until 802.1X succeeds, and an unauthorized port drops everything --
# including DHCP -- so non-supplicants get no address at all. The "drop them on
# Guest instead" behaviour is the site-wide 802.1X Fallback VLAN, which lives in
# Global Switch Settings (`global_switch.dot1x_fallback_networkconf_id`), not on the
# port profile: there is no per-profile guest/fallback attribute in the schema.
#
# FIXME(unifi): `unifi_setting` exposes no switch/dot1x block at v0.55.0, so the
# fallback VLAN cannot be managed here. Set manually to Guest -- see
# docs/unifi-browser-changes.md (2026-09-08) and the commented
# `unifi_setting_switch` block in ../system/settings.tf.
#
# native_networkconf_id is Main, not Guest: with the fallback VLAN doing the
# unauthenticated case, the native VLAN is what an *authorized* client gets when
# RADIUS returns no VLAN assignment, and that should be Main.
resource "unifi_port_profile" "host_device" {
  name                  = "Host Device"
  forward               = "customize"
  native_networkconf_id = unifi_network.main.id
  poe_mode              = "auto"
  autoneg               = true
  dot1x_ctrl            = "auto"
  tagged_vlan_mgmt      = "auto"
  setting_preference    = "manual"
  stp_port_mode         = true # Services -> STP (not Port Mode, see header)
}

# ----------------------------------------------------------------------------
# Per-VLAN access profiles for wired servers and IoT gear. Recreated on the
# controller by hand on 2026-09-13 (verified via /rest/portconf). Untagged on
# the named VLAN, no 802.1X (force_authorized), Port Mode: Edge like Host Device
# (stp_edge_state, UI-only -- see header). Assigning ports to them is the
# TODO(port-overrides) work in ../devices/*.tf.
# ----------------------------------------------------------------------------

resource "unifi_port_profile" "public_servers" {
  name                  = "Public Server"
  forward               = "customize"
  native_networkconf_id = unifi_network.public_servers.id
  poe_mode              = "auto"
  autoneg               = true
  dot1x_ctrl            = "force_authorized"
  tagged_vlan_mgmt      = "auto"
  setting_preference    = "manual"
  stp_port_mode         = true # Services -> STP (not Port Mode, see header)
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
  stp_port_mode         = true # Services -> STP (not Port Mode, see header)
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
  stp_port_mode         = true # Services -> STP (not Port Mode, see header)
}
