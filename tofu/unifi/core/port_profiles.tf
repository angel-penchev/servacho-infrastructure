# ----------------------------------------------------------------------------
# Port profiles
#
# All five exist on the controller. The three per-VLAN ones were destroyed by the 2026-09
# factory reset and recreated by hand, named in the singular to match the `UniFi Device` /
# `Host Device` convention already in place.
# ----------------------------------------------------------------------------

# Uplinks between UniFi devices themselves. Trunks every VLAN and never runs 802.1X,
# otherwise the infrastructure could not come up before RADIUS is reachable.
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

# Host-facing access ports on the USW Pro Max 24 PoE: 802.1X pass -> RADIUS returns
# Tunnel-Private-Group-ID 2 -> Main; fail or no supplicant -> Guest.
#
# FIXME(unifi): that second half is not expressible here. An unauthorized port drops
# everything including DHCP, so the "drop them on Guest instead" behaviour is the
# site-wide 802.1X Fallback VLAN (`global_switch.dot1x_fallback_networkconf_id`), and
# `unifi_setting` exposes no switch/dot1x block at v0.55.0. Set manually to Guest -- see
# the commented `unifi_setting_switch` block in ../system/settings.tf.
#
# native_networkconf_id is Main, not Guest: with the fallback VLAN handling the
# unauthenticated case, the native VLAN is what an *authorized* client gets when RADIUS
# returns no VLAN assignment.
#
# Not for appliances without a supplicant -- two of those sat here and were silently
# fallback-dumped onto Guest. Both moved to a per-VLAN profile below.
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

# ----------------------------------------------------------------------------
# Per-VLAN access profiles.
#
# All three force-authorize 802.1X: they are for appliances and servers with no
# supplicant, where leaving dot1x_ctrl on "auto" is what caused the fallback-to-Guest
# problem above.
#
# `stp_port_mode = true` and `setting_preference = "manual"` match what the UI produces
# and what all five live profiles carry. `stp_port_mode` is the plain "STP" checkbox, NOT
# the UI's "Port Mode: Infrastructure/Edge" control -- that one is `stp_edge_state`.
#
# FIXME(unifi): `stp_edge_state` cannot be managed here. go-unifi carries it
# (`unifi/port_profile.generated.go`), the provider does not expose it on v0.55.0 --
# a provider-only PR, unlike the two-repo mDNS gap.
#
# It matters: a non-Edge access port runs full STP and holds the link in
# listening/learning for ~15-30s after link-up, dropping the DHCP handshake of whatever
# is plugged in. All three were created as Infrastructure (the UI default) and set to
# Edge by hand. If an apply ever recreates them they come back as Infrastructure and need
# fixing in the UI again. `UniFi Device` stays non-Edge on purpose -- it is for
# switch-to-switch uplinks, where STP participation is the point.
#
# The `port_override` blocks in ../devices/*.tf that reference these profiles record
# intent only: every switch carries `lifecycle { ignore_changes = [port_override] }`
# because of upstream #430 / #438, so assignment happens in the admin panel.
#
# TODO(port-security): both server profiles should eventually restrict which MACs may
# appear on a server port. `port_security_enabled` and `port_security_mac_address` exist
# at v0.55.0, but an explicitly empty allowlist collapses to SetNull and errors on every
# apply (upstream #470, ours, open) -- so only declare them with real MACs in them.
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
