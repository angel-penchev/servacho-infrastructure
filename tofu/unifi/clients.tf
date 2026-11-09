# Fixed-IP reservations, attribute-exact against live. A reservation cleared in the UI
# is mirrored with fixed_ip = "": deleting the resource would make the controller forget
# the client.

# Proxmox host: USW Pro Max port 21 while its Aggregation port 1 link is out.
resource "unifi_client" "servacho_gosho" {
  mac            = "38:05:25:30:79:97"
  name           = "Servacho-Gosho"
  fixed_ip       = "192.168.5.10"
  allow_existing = true
}

# The root management plane, VM 5015. Its address is static in the host
# configuration; the reservation keeps DHCP from handing .15 to anything else.
resource "unifi_client" "servacho_management_plane" {
  mac            = "bc:24:11:5a:ab:e2"
  name           = "servacho-management-plane"
  fixed_ip       = "192.168.5.15"
  allow_existing = true
}

# The organisations' management planes (tofu/organisation/plane.tf). Their
# addresses are static and outside DHCP; the entries name them and record the
# address, as for the root plane.
resource "unifi_client" "qoax_community_management_plane" {
  mac            = "bc:24:11:0c:b4:13"
  name           = "qoax-community-management-plane"
  fixed_ip       = "192.168.10.15"
  allow_existing = true
}

# USW Pro Max port 12.
resource "unifi_client" "jetkvm_servacho_gosho" {
  mac      = "30:52:53:0a:09:87"
  name     = "JetKVM-Servacho-Gosho"
  fixed_ip = "192.168.5.20"
  # FIXME(unifi): live binds this reservation to Private Servers (the client record's
  #   network_id, set with the fixed IP), and no provider attribute maps it. The
  #   resource's network_id is UniFi's Network Override: never declare it here, the
  #   apply would switch the override on. Updates keep the binding; a create does not
  #   set it, so a rebuilt reservation is re-bound by hand (PUT /rest/user with
  #   network_id, see docs/unifi-browser-changes.md).
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

# The Mac mini running Unity Intercom Server, USW Pro Max port 19 (Public
# Server profile). The intercom's port forward points at this address.
resource "unifi_client" "mac4o_mini" {
  mac      = "1c:f6:4c:47:5b:c6"
  name     = "mac4o-mini"
  fixed_ip = "192.168.4.24"
  # FIXME(unifi): live binds this reservation to Public Servers the same way; never
  #   declare network_id here either (see jetkvm_servacho_gosho).
  allow_existing = true
}
