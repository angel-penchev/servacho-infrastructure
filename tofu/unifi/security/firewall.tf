# ----------------------------------------------------------------------------
# Firewall Zones
# ----------------------------------------------------------------------------

data "unifi_firewall_zone" "internal" {
  name = "Internal"
}

# The DMZ zone is a default zone built into the UniFi controller. 
# We manage it here to explicitly attach the Public Servers network.
# Name is "Dmz", not "DMZ" -- that is the exact casing the controller reports.
resource "unifi_firewall_zone" "dmz" {
  name = "Dmz"

  network_ids = [
    var.network_public_servers_id
  ]
}

# The Hotspot zone holds the Guest network.
#
# This is not just completeness: on zone-based-firewall controllers a network only
# keeps `purpose = "guest"` while it belongs to the guest/Hotspot zone -- placed
# anywhere else the controller silently rewrites it back to "corporate" (upstream
# #276, provider v0.54.0). unifi_network.guest declares purpose = "guest", so this
# zone assignment is what makes that stick.
resource "unifi_firewall_zone" "hotspot" {
  name = "Hotspot"

  network_ids = [
    var.network_guest_id
  ]
}

# The IoT network gets its own zone so traffic to and from it is filterable at all.
#
# Until 2026-09-09 IoT sat in Internal alongside Main and Private Servers, and the
# Internal->Internal pair carries the predefined `ALLOW Allow All Traffic` -- so the
# intended "Main reaches IoT, IoT does not reach Main" asymmetry was not in force in
# either direction, and `allow_main_to_iot` below was a no-op. A zone boundary is what
# makes the policies further down apply: same-zone traffic in one network never reaches
# a policy, and same-VLAN traffic never even reaches the gateway.
#
# purpose stays "corporate" here, so the guest/Hotspot coupling noted above (#276)
# does not apply.
#
# Created by hand in the admin panel on 2026-09-09 (see docs/unifi-browser-changes.md);
# creating it auto-paused `allow_main_to_iot` and cleared its destination.
# zone id `6aa12f7b40324b4491452cf5`. This resource therefore needs
#   tofu import unifi_firewall_zone.iot 6aa12f7b40324b4491452cf5
# before an apply will accept it -- a custom zone cannot be imported by name the way the
# built-in Internal/Hotspot/Dmz zones can.
resource "unifi_firewall_zone" "iot" {
  name = "IoT"

  network_ids = [
    var.network_iot_id
  ]
}

# ----------------------------------------------------------------------------
# Address groups
# ----------------------------------------------------------------------------

# The two TVs that Guest clients are allowed to reach: the EON/SDMC Android TV box in
# the living room (192.168.6.10, wired to Pro Max port 6) and the Sony BRAVIA in the
# bedroom (192.168.6.11, Wi-Fi on StKr_IoT).
#
# Matched by IP rather than MAC on purpose. The BRAVIA presented a randomized,
# locally-administered MAC (52:4b:e7:...) which it is free to rotate per SSID; the
# addresses are pinned by DHCP reservation instead, so a rotation can only break the
# reservation, never silently widen or void this policy.
# Created by hand 2026-09-09, id `6aa1316d40324b4491452f98` -- needs `tofu import` too.
resource "unifi_firewall_group" "tv_media_endpoints" {
  name = "TV Media Endpoints"
  type = "address-group"

  members = [
    "192.168.6.10",
    "192.168.6.11",
  ]
}

# ----------------------------------------------------------------------------
# Firewall Policies
# ----------------------------------------------------------------------------

# NOTE: policy ordering cannot be managed through the provider. `index` is a
# per-zone-pair, controller-assigned ordinal; the integration API rejects it as input
# and the v2 endpoint ignores it and appends (upstream #348, read-only since v0.54.0).
# Every policy below lands wherever the controller decides to put it in its pair.
#
# That turns out not to matter here, and there is deliberately NO explicit
# "block IoT from initiating" policy. Verified on the live controller 2026-09-09, right
# after the IoT zone was created:
#
#   IoT -> Internal   BLOCK "Block All Traffic"  predefined, index 2147483647
#   IoT -> Hotspot    BLOCK "Block All Traffic"  predefined, index 2147483647
#   IoT -> Vpn/Dmz    BLOCK "Block All Traffic"  predefined, index 2147483647
#   IoT -> External   ALLOW "Allow All Traffic"  predefined  (internet still works)
#   IoT -> Gateway    ALLOW "Allow All Traffic" + "Allow mDNS"
#
# A newly created custom zone is blocked from every zone except External and Gateway by
# default -- the Create Zone dialog states this outright. So the "Main reaches IoT, IoT
# does not reach Main" asymmetry is delivered by the zone boundary itself, and the three
# ALLOW policies below are what open the specific paths back up. They sit at index
# ~10000, far ahead of the predefined catch-all block at 2147483647, so ordering between
# them and the block is not in question.
#
# Do NOT add a redundant `BLOCK IoT -> Internal` policy "for explicitness": it duplicates
# a predefined rule and buys nothing.
#
# (Historical note: an earlier draft of this work reasoned from
# `global_network.default_security_posture = "ALLOW_ALL"` that a new zone pair would
# default to *allow* and therefore needed an explicit NEW-only BLOCK. That was wrong --
# ALLOW_ALL governs the built-in zones' predefined policies, not user-created zones.)

# Main -> IoT. Destination is the IoT zone rather than a network inside Internal: before
# the IoT zone existed this was an Internal->Internal policy sitting behind the predefined
# `ALLOW Allow All Traffic`, i.e. a no-op with 2,996 hits it never needed to match.
#
# Moving the IoT network into its own zone auto-paused this policy and cleared its
# destination (the controller warns about exactly this). Retargeted and re-enabled by hand
# on 2026-09-09; `create_allow_respond` regenerated the "Allow Main to IoT (Return)"
# companion in the IoT->Internal pair.
resource "unifi_firewall_policy" "allow_main_to_iot" {
  name                 = "Allow Main to IoT"
  action               = "ALLOW"
  ip_version           = "BOTH"
  protocol             = "all"
  create_allow_respond = true
  logging              = false

  source = {
    zone_id         = data.unifi_firewall_zone.internal.id
    matching_target = "NETWORK"
    network_ids = [
      var.network_main_id
    ]
  }

  destination = {
    zone_id         = unifi_firewall_zone.iot.id
    matching_target = "ANY"
  }
}

# Private Servers -> IoT, for Home Assistant (192.168.5.226) to keep polling and
# commanding the IoT devices.
#
# Home Assistant stays on Private Servers rather than moving onto IoT deliberately: it
# holds credentials for every device on that VLAN, and same-VLAN traffic never reaches
# the gateway, so co-locating it would put its admin UI and tokens in front of every
# bulb and TV with no policy able to filter it. It reached IoT via the Internal
# allow-all before the zone split, so without this policy it would break.
resource "unifi_firewall_policy" "allow_private_servers_to_iot" {
  name                 = "Allow Private Servers to IoT"
  action               = "ALLOW"
  ip_version           = "BOTH"
  protocol             = "all"
  create_allow_respond = true
  logging              = false

  source = {
    zone_id         = data.unifi_firewall_zone.internal.id
    matching_target = "NETWORK"
    network_ids = [
      var.network_private_servers_id
    ]
  }

  destination = {
    zone_id         = unifi_firewall_zone.iot.id
    matching_target = "ANY"
  }
}

# Guest -> the two TVs only, so visitors can cast without reaching the rest of IoT.
#
# matching_target_type is deliberately not set: it is read-only in the schema, and the
# provider derives OBJECT from a non-empty ip_group_id. The controller rejects a group
# reference sent as SPECIFIC, which is what upstream #365 fixed in v0.55.0 -- our pin.
#
# Note that mDNS discovery is a separate mechanism from this unicast permission: the
# site-wide Gateway mDNS Proxy is what lets a Guest phone *see* the TVs, and this policy
# is what lets it actually stream to them. See ../system/mdns.tf.
resource "unifi_firewall_policy" "allow_guest_to_tvs" {
  name                 = "Allow Guest to TVs"
  action               = "ALLOW"
  ip_version           = "BOTH"
  protocol             = "all"
  create_allow_respond = true
  logging              = false

  source = {
    zone_id         = unifi_firewall_zone.hotspot.id
    matching_target = "NETWORK"
    network_ids = [
      var.network_guest_id
    ]
  }

  destination = {
    zone_id         = unifi_firewall_zone.iot.id
    matching_target = "IP"
    ip_group_id     = unifi_firewall_group.tv_media_endpoints.id
  }
}
