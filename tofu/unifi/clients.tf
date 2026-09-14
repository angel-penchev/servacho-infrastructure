# Fixed-IP reservations, attribute-exact against live (2026-09-13). Only the port-12
# JetKVM carries a network binding, because live does.
#
# FIXME(unifi): at v0.55.0 every in-place unifi_client update fails with "inconsistent
#   result after apply: .last_ip" (upstream #428, fixed on main as #447, unreleased).
#   Creates and no-op plans are fine, so: import before the first plan, and change
#   attributes in the UI first, then mirror.

# Proxmox host, USW Aggregation port 1.
resource "unifi_client" "servacho_gosho" {
  mac            = "38:05:25:30:79:97"
  name           = "Servacho-Gosho"
  fixed_ip       = "192.168.5.10"
  allow_existing = true
}

# USW Pro Max port 12.
resource "unifi_client" "jetkvm_servacho_gosho" {
  mac      = "30:52:53:0a:09:87"
  name     = "JetKVM-Servacho-Gosho"
  fixed_ip = "192.168.5.20"
  # FIXME(unifi): no network_id declared although live HAS one (Private Servers, verified
  #   2026-09-14). The provider's unifi_client Read does not populate network_id, so
  #   declaring it plans an in-place update on every run -- which #428 cannot perform.
  #   Re-add `network_id = unifi_network.private_servers.id` once Read maps it.
  allow_existing = true
}

# USW Pro Max port 18.
resource "unifi_client" "jetkvm_michelangelo" {
  mac            = "30:52:53:0d:1a:68"
  name           = "JetKVM-Michelangelo"
  fixed_ip       = "192.168.5.23"
  allow_existing = true
}

resource "unifi_client" "fmicodes_master_node" {
  mac            = "bc:24:11:c3:e5:f4"
  name           = "fmicodes-master-node"
  fixed_ip       = "192.168.5.200"
  allow_existing = true
}

resource "unifi_client" "fmicodes_worker_node_1" {
  mac            = "bc:24:11:23:76:b5"
  name           = "fmicodes-worker-node-1"
  fixed_ip       = "192.168.5.201"
  allow_existing = true
}

resource "unifi_client" "hackjamhub_intercom" {
  mac            = "bc:24:11:8a:b7:98"
  name           = "hackjamhub-intercom"
  fixed_ip       = "192.168.5.215"
  allow_existing = true
}

# USW Pro Max port 6.
resource "unifi_client" "living_room_tv" {
  mac            = "b0:b3:69:41:2c:9b"
  name           = "Living Room TV"
  fixed_ip       = "192.168.6.10"
  allow_existing = true
}

resource "unifi_client" "bedroom_tv" {
  mac            = "f4:4e:b4:73:bf:19"
  name           = "Bedroom TV"
  fixed_ip       = "192.168.6.11"
  allow_existing = true
}
