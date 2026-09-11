# ----------------------------------------------------------------------------
# Firewall Zones
# ----------------------------------------------------------------------------

data "unifi_firewall_zone" "internal" {
  name = "Internal"
}

# Built-in zone. The controller spells it "Dmz", not "DMZ".
resource "unifi_firewall_zone" "dmz" {
  name = "Dmz"

  network_ids = [
    var.network_public_servers_id
  ]
}

# A network only keeps `purpose = "guest"` while it sits in this zone -- anywhere else
# the controller rewrites it back to "corporate" (upstream #276).
resource "unifi_firewall_zone" "hotspot" {
  name = "Hotspot"

  network_ids = [
    var.network_guest_id
  ]
}

# IoT needs its own zone to be filterable at all: it used to sit in Internal alongside
# Main, where the predefined Internal->Internal allow-all made the policies below no-ops.
#
# Created by hand, so this needs
#   tofu import unifi_firewall_zone.iot 6aa12f7b40324b4491452cf5
# before an apply will accept it -- custom zones cannot be imported by name.
resource "unifi_firewall_zone" "iot" {
  name = "IoT"

  network_ids = [
    var.network_iot_id
  ]
}

# ----------------------------------------------------------------------------
# Firewall Policies
#
# Policy ordering cannot be managed here: `index` is controller-assigned and read-only
# (upstream #348). It does not matter, because a custom zone is blocked from every zone
# except External and Gateway by default, and these ALLOWs land at ~10000, far ahead of
# the predefined catch-all block at 2147483647.
#
# For the same reason there is deliberately no `BLOCK IoT -> Internal` policy: the
# predefined one already covers it. Do not add one "for explicitness".
# ----------------------------------------------------------------------------

# Destination is the IoT zone rather than a network inside Internal. Moving IoT into its
# own zone auto-paused this policy and cleared its destination; retargeted by hand.
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

# Home Assistant (192.168.5.226) polls and commands the IoT devices. It stays on Private
# Servers rather than moving onto IoT because same-VLAN traffic never reaches the gateway,
# so co-locating it would expose its admin UI and tokens to every device with no policy
# able to filter it. It reached IoT via the Internal allow-all before the zone split.
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

# ----------------------------------------------------------------------------
# Guest access to the TVs -- abandoned 2026-09-11, do not reinstate blindly
#
# A `TV Media Endpoints` address group and an `Allow Guest to TVs` policy used to sit
# here. For a guest network the zone firewall is not the enforcement point: clients of a
# Hotspot-zone network are flagged `is_guest` and the APs enforce isolation locally,
# ahead of any zone policy. All three Hotspot->IoT policies read zero hits after real
# cast attempts, so the ALLOW was never consulted -- while still reading, in the policy
# table, as though Guest could reach the TVs.
#
# Making it work needs the Guest network out of the Hotspot zone entirely, trading
# UniFi's built-in guest isolation for hand-written policy. Declined. Full diagnosis in
# docs/unifi-browser-changes.md.
# ----------------------------------------------------------------------------
