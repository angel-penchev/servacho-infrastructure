# The management plane's reservation of 192.168.5.15 is made in the UniFi UI
# first, since every in-place unifi_client update fails at v0.55.0
# (tofu/unifi/clients.tf), and adopted here. Inert once the client is in state;
# remove it in a later change.
import {
  id = "bc:24:11:5a:ab:e2"
  to = module.unifi.unifi_client.servacho_management_plane
}
