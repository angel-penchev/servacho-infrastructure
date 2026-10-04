# The organisations' management planes are named and their addresses recorded
# in the UniFi UI first, since every in-place unifi_client update fails at
# v0.55.0 (tofu/unifi/clients.tf), and adopted here. Inert once the clients are
# in state; remove it in a later change.
import {
  id = "bc:24:11:0c:b4:13"
  to = module.unifi.unifi_client.qoax_community_management_plane
}

import {
  id = "bc:24:11:9d:30:04"
  to = module.unifi.unifi_client.fmicodes_management_plane
}
