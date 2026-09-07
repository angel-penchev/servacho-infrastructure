# ----------------------------------------------------------------------------
# Port profiles
#
# Only two profiles exist on the controller after the 2026-09 rebuild. Both are
# declared here. The three per-VLAN profiles further down are TODO: they were
# wiped by the factory reset and have not been recreated.
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
  stp_port_mode         = true # "Port Mode: Edge" in the UI
}

# ----------------------------------------------------------------------------
# TODO(port-profiles): the three per-VLAN profiles below were destroyed by the
# factory reset and have NOT been recreated on the controller. Nothing on any
# switch references a per-VLAN profile any more -- the two server/IoT ports that
# used to use one now carry inline native-VLAN overrides instead.
#
# Decide per profile whether to recreate it or delete it outright. Kept as-is for
# now so the port_override blocks in ../devices/*.tf (themselves TODO, see
# docs/unifi-manual-vs-tofu.md 3.2-3.4) still resolve.
# ----------------------------------------------------------------------------

resource "unifi_port_profile" "public_servers" {
  name                  = "Public Servers"
  forward               = "customize"
  native_networkconf_id = unifi_network.public_servers.id
  poe_mode              = "auto"
  autoneg               = true
  dot1x_ctrl            = "force_authorized"
  tagged_vlan_mgmt      = "auto"
  stp_port_mode         = false
}

resource "unifi_port_profile" "private_servers" {
  name                  = "Private Servers"
  forward               = "customize"
  native_networkconf_id = unifi_network.private_servers.id
  poe_mode              = "auto"
  autoneg               = true
  dot1x_ctrl            = "force_authorized"
  tagged_vlan_mgmt      = "auto"
  stp_port_mode         = false
}

resource "unifi_port_profile" "iot" {
  name                  = "IoT"
  forward               = "customize"
  native_networkconf_id = unifi_network.iot.id
  poe_mode              = "auto"
  autoneg               = true
  dot1x_ctrl            = "force_authorized"
  tagged_vlan_mgmt      = "auto"
  stp_port_mode         = false
}
