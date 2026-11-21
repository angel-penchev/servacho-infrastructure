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
