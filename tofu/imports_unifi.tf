# The SUGAMING plane's client was named and given its fixed IP on the
# controller first (docs/unifi-browser-changes.md) and is adopted here by MAC.
# The block is inert once applied; remove it in a later change.
import {
  id = "bc:24:11:85:1b:83"
  to = module.unifi.unifi_client.sugaming_management_plane
}

# The SRT forward was made in the UniFi UI first
# (docs/unifi-browser-changes.md) and is adopted here by its _id. The block
# is inert once applied; remove it in a later change.
import {
  id = "6afeb74bb09f1dba7f87d586"
  to = module.unifi.unifi_port_forward.broadcast_srt
}

# The SRT camera forward was made in the UniFi UI first
# (docs/unifi-browser-changes.md) and is adopted here by its _id. The block
# is inert once applied; remove it in a later change.
import {
  id = "6affbfdcb09f1dba7f88a69e"
  to = module.unifi.unifi_port_forward.broadcast_srt_cameras
}

# The Unity Intercom tally forward was made in the UniFi UI first
# (docs/unifi-browser-changes.md) and is adopted here by its _id. The block
# is inert once applied; remove it in a later change.
import {
  id = "6b020c3bb09f1dba7f8c0ed8"
  to = module.unifi.unifi_port_forward.unity_intercom_tally
}

# UniFi Network 11.0.104 gave every firewall zone and policy a UUID in place
# of its _id (between 2026-11-21 and 2026-11-22). Read by the old ids, these
# five went "deleted" and planned a re-create, although all five still exist
# live. They are adopted again here by their new ids, read from
# GET /proxy/network/v2/api/site/default/firewall/zone and firewall-policies.
# The blocks are inert once applied; remove them in a later change.
import {
  id = "d8c27cf6-4f12-4023-beff-c1eef6839f03"
  to = module.unifi.unifi_firewall_zone.dmz
}

import {
  id = "dc6f1fcc-9c6a-499d-b9a7-3855c7e7f1ea"
  to = module.unifi.unifi_firewall_zone.hotspot
}

import {
  id = "b494d052-95cb-4d2b-ad45-0d6c375838ab"
  to = module.unifi.unifi_firewall_zone.iot
}

import {
  id = "c06ab890-519b-4431-b84a-1fcac85d18e5"
  to = module.unifi.unifi_firewall_policy.allow_main_to_iot
}

import {
  id = "eb57d467-2147-4f78-9c93-442306a61181"
  to = module.unifi.unifi_firewall_policy.allow_private_servers_to_iot
}
