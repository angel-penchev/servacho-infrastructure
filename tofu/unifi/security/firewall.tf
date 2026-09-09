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
# IoT has sat in Internal alongside Main and Private Servers since the rebuild, and the
# Internal->Internal pair carries the predefined `ALLOW Allow All Traffic` -- so the
# intended "Main reaches IoT, IoT does not reach Main" asymmetry was not in force in
# either direction, and `allow_main_to_iot` below was a no-op. A zone boundary is what
# makes the policies further down apply: same-zone traffic in one network never reaches
# a policy, and same-VLAN traffic never even reaches the gateway.
#
# purpose stays "corporate" here, so the guest/Hotspot coupling noted above (#276)
# does not apply.
#
# Note: this zone is created by hand in the admin panel first (see the pending checklist
# in docs/unifi-browser-changes.md), so the resource then needs
# `tofu import unifi_firewall_zone.iot <zone-id>` before an apply will accept it -- a
# custom zone cannot be imported by name, only built-ins can.
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
# That constraint is why the IoT block is scoped to connection_states = ["NEW"] rather
# than being a plain BLOCK. `global_network.default_security_posture` on this site is
# ALLOW_ALL, so a new zone pair permits everything until a policy says otherwise, and a
# blanket `BLOCK IoT -> Internal` would have to land *after* the return-traffic
# companion that `create_allow_respond` generates in that same pair to avoid killing
# replies to Main-initiated sessions -- which is exactly what cannot be guaranteed.
# Matching only NEW makes the result order-independent: IoT can never initiate into
# Internal, established/related returns always pass. Do not "simplify" this back into
# an unordered blanket BLOCK.
#
# connection_state_type / connection_states became author-settable in provider v0.54.0
# (upstream #351); before that this design was not expressible here at all.

# Stops IoT devices initiating anything towards Main, Private Servers or the other
# Internal networks. This is the policy that actually delivers the intended asymmetry.
resource "unifi_firewall_policy" "block_iot_initiated" {
  name                  = "Block IoT Initiated"
  action                = "BLOCK"
  ip_version            = "BOTH"
  protocol              = "all"
  create_allow_respond  = false
  logging               = false
  connection_state_type = "CUSTOM"
  connection_states     = ["NEW"]

  source = {
    zone_id         = unifi_firewall_zone.iot.id
    matching_target = "ANY"
  }

  destination = {
    zone_id         = data.unifi_firewall_zone.internal.id
    matching_target = "ANY"
  }
}

# Main -> IoT. Destination is now the IoT zone rather than a network inside Internal:
# before the IoT zone existed this was an Internal->Internal policy sitting behind the
# predefined allow-all, i.e. a no-op.
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
