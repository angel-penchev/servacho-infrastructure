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

# FIXME(unifi): policy ordering is read-only -- `index` is controller-assigned and the
#   API ignores it on write (upstream #348). This lands wherever the controller puts it
#   in the Internal -> Internal pair.
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
    zone_id         = data.unifi_firewall_zone.internal.id
    matching_target = "NETWORK"
    network_ids = [
      unifi_network.iot.id
    ]
  }
}
