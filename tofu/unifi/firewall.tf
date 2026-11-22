data "unifi_firewall_zone" "internal" {
  name = "Internal"
}

# Built-in zone; managed only to pin the networks of hosts the internet reaches
# to it. Its predefined policies block new connections from it to every other
# zone but External, between its own networks, and to the gateway but DNS, DHCP
# and ICMP. The controller spells it "Dmz".
resource "unifi_firewall_zone" "dmz" {
  name = "Dmz"

  # Live order since Network 11.0.104; the other order plans a rewrite.
  network_ids = [
    unifi_network.qoax_public_servers.id,
    unifi_network.public_servers.id,
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
# it from every other zone. Traffic into it is opened per
# source network by the policies below.
resource "unifi_firewall_zone" "iot" {
  name = "IoT"

  network_ids = [
    unifi_network.iot.id
  ]
}

# FIXME(unifi): policy ordering cannot be managed (upstream #348): `index` is
#   controller-assigned and computed only, and the provider has no reorder call. Live:
#   10000 and 10001 in the Internal -> IoT pair, ahead of the predefined block.
# Both policies mirror live: whole IoT zone as destination, respond
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

# Unity Intercom Server on mac4o-mini plays the venue's vMix audio into a
# channel (docs/unity-intercom.md): it reads the SRT relay's feed as a home
# reader. Both hosts are in Dmz, whose predefined policies block traffic
# between its own networks, so this opens only that one flow. The address is
# the relay's static one from qoax-infrastructure, as in port_forwards.tf.
resource "unifi_firewall_policy" "allow_intercom_to_srt_relay" {
  name                 = "Allow Intercom to SRT relay"
  action               = "ALLOW"
  ip_version           = "IPV4"
  protocol             = "udp"
  create_allow_respond = true
  logging              = false

  source = {
    zone_id         = unifi_firewall_zone.dmz.id
    matching_target = "IP"
    ips             = [unifi_client.mac4o_mini.fixed_ip]
  }

  destination = {
    zone_id            = unifi_firewall_zone.dmz.id
    matching_target    = "IP"
    ips                = ["192.168.12.23"]
    port_matching_type = "SPECIFIC"
    port               = "8890"
  }
}
