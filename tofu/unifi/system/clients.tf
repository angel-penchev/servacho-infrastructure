# Fixed-IP reservations. Mirrors the live controller exactly as of 2026-09-13: eight
# entries, all named on the controller (the six Private Servers ones were named via
# the API on 2026-09-13 and mirrored here the same minute). Only the port-12 JetKVM
# has a network binding.
#
# FIXME(unifi): at v0.55.0 EVERY in-place unifi_client update fails with
# "inconsistent result after apply: .last_ip" (upstream #428, fixed on main as #447,
# unreleased). Creates and no-op plans are fine. So: keep these blocks identical to
# live, import them before the first plan, and do not add attributes (name, note,
# network_id) here before v0.56.0 -- set them in the UI first, then mirror.
# https://github.com/ubiquiti-community/terraform-provider-unifi/issues/428

# Proxmox host, uplinked on USW Aggregation port 1 (Private Server profile).
resource "unifi_client" "servacho_gosho" {
  mac            = "38:05:25:30:79:97"
  name           = "Servacho-Gosho"
  fixed_ip       = "192.168.5.10"
  allow_existing = true
}

# JetKVM on USW Pro Max port 12 (hostname jetkvm-4562a8bf464c58c8).
resource "unifi_client" "jetkvm_servacho_gosho" {
  mac            = "30:52:53:0a:09:87"
  name           = "JetKVM-Servacho-Gosho"
  fixed_ip       = "192.168.5.20"
  network_id     = var.network_private_servers_id
  allow_existing = true
}

# JetKVM on USW Pro Max port 18 (hostname jetkvm-ce4ac3437e0d935d).
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

# USW Pro Max port 6 (IoT Device profile).
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
