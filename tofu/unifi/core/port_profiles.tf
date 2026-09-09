# ----------------------------------------------------------------------------
# Port profiles
#
# The three per-VLAN profiles were destroyed by the 2026-09 factory reset. Their
# recreation was authorised on 2026-09-09 but is a manual admin-panel step that has
# NOT been carried out yet -- see the pending checklist in
# docs/unifi-browser-changes.md. They are named in the singular to match the
# `UniFi Device` / `Host Device` convention already on the controller.
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
#
# Note: this profile is deliberately NOT for appliances without a supplicant. Two
# of those (the EON TV box on port 6, a JetKVM on port 18) sit here today and are
# silently fallback-dumped onto Guest as a result; both are moving to a per-VLAN
# profile below.
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
# Per-VLAN access profiles.
#
# To be created on the controller in VLAN-ID order (Public Server 4, Private
# Server 5, IoT Device 6). All three force-authorize 802.1X: they are for
# appliances and servers with no supplicant, so leaving dot1x_ctrl on "auto" is
# exactly what caused the fallback-to-Guest problem described above.
#
# Intended port assignments (authorised 2026-09-09, applied in the admin panel):
#   IoT Device     -> USW Pro Max 24 PoE port 6  (LR-06, EON TV box)
#   Private Server -> USW Pro Max 24 PoE port 18 (BR-02, JetKVM)
#   Public Server  -> no port yet
#
# Note: the `port_override` blocks in ../devices/*.tf that reference these
# profiles are decorative. Every switch carries
# `lifecycle { ignore_changes = [port_override] }` because of upstream #430 /
# #438, so port assignment happens in the admin panel and the code only records
# intent -- see docs/unifi-manual-vs-tofu.md 3.4.
#
# TODO(port-security): both server profiles should eventually restrict which MACs
# may appear on a server port. `port_security_enabled` and
# `port_security_mac_address` exist in the schema at v0.55.0, but an explicitly
# empty allowlist collapses to SetNull and errors on every apply (upstream #470,
# ours, still open) -- so only declare them together with real MAC addresses.
# Until then anything plugged into a server port is allowed, by decision.
# ----------------------------------------------------------------------------

resource "unifi_port_profile" "public_servers" {
  name                  = "Public Server"
  forward               = "customize"
  native_networkconf_id = unifi_network.public_servers.id
  poe_mode              = "auto"
  autoneg               = true
  dot1x_ctrl            = "force_authorized"
  tagged_vlan_mgmt      = "auto"
  stp_port_mode         = false
}

resource "unifi_port_profile" "private_servers" {
  name                  = "Private Server"
  forward               = "customize"
  native_networkconf_id = unifi_network.private_servers.id
  poe_mode              = "auto"
  autoneg               = true
  dot1x_ctrl            = "force_authorized"
  tagged_vlan_mgmt      = "auto"
  stp_port_mode         = false
}

resource "unifi_port_profile" "iot" {
  name                  = "IoT Device"
  forward               = "customize"
  native_networkconf_id = unifi_network.iot.id
  poe_mode              = "auto"
  autoneg               = true
  dot1x_ctrl            = "force_authorized"
  tagged_vlan_mgmt      = "auto"
  stp_port_mode         = false
}
