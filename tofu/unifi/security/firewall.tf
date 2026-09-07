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

# ----------------------------------------------------------------------------
# Firewall Policies
# ----------------------------------------------------------------------------

# NOTE: policy ordering cannot be managed through the provider. `index` is a
# per-zone-pair, controller-assigned ordinal; the integration API rejects it as input
# and the v2 endpoint ignores it and appends (upstream #348, read-only since v0.54.0).
# This policy lands wherever the controller puts it in the Internal->Internal pair.
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
    zone_id         = data.unifi_firewall_zone.internal.id
    matching_target = "NETWORK"
    network_ids = [
      var.network_iot_id
    ]
  }
}
