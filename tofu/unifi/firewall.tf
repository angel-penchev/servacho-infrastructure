data "unifi_firewall_zone" "internal" {
  name = "Internal"
}

# Built-in zone; managed only to pin the Public Servers network to it. The
# controller spells it "Dmz".
resource "unifi_firewall_zone" "dmz" {
  name = "Dmz"

  network_ids = [
    unifi_network.public_servers.id
  ]
}

# Guest must live here: a network keeps purpose = "guest" only while it is in the
# Hotspot zone, otherwise the controller silently rewrites it to "corporate"
# (upstream #276).
resource "unifi_firewall_zone" "hotspot" {
  name = "Hotspot"

  network_ids = [
    unifi_network.guest.id
  ]
}

# Custom zone holding the IoT network so the default inter-zone "block" applies to
# it from every other zone (created live 2026-09-13). Traffic into it is opened per
# source network by the policies below.
resource "unifi_firewall_zone" "iot" {
  name = "IoT"

  network_ids = [
    unifi_network.iot.id
  ]
}

# FIXME(unifi): policy ordering is read-only -- `index` is controller-assigned and the
#   API ignores it on write (upstream #348). Live: 10000 and 10001 in the Internal -> IoT
#   pair, ahead of the predefined block.
# Both policies mirror live (2026-09-14): whole IoT zone as destination, respond
# traffic allowed, all protocols, always on, no logging.
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
      unifi_network.main.id
    ]
  }

  destination = {
    zone_id         = unifi_firewall_zone.iot.id
    matching_target = "ANY"
  }
}

# Home Assistant and friends on Private Servers reach the IoT gear.
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
      unifi_network.private_servers.id
    ]
  }

  destination = {
    zone_id         = unifi_firewall_zone.iot.id
    matching_target = "ANY"
  }
}
