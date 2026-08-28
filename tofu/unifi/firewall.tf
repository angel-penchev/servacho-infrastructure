# ----------------------------------------------------------------------------
# Firewall Zones
# ----------------------------------------------------------------------------

data "unifi_firewall_zone" "internal" {
  name = "Internal"
}

# The DMZ zone is a default zone built into the UniFi controller. 
# We manage it here to explicitly attach the Public Servers network.
resource "unifi_firewall_zone" "dmz" {
  name = "DMZ"

  network_ids = [
    unifi_network.public_servers.id
  ]
}

# ----------------------------------------------------------------------------
# Firewall Policies
# ----------------------------------------------------------------------------

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
