# The Mac mini's fixed IP is set in the UniFi UI first, since every in-place
# unifi_client update fails at v0.55.0 (tofu/unifi/clients.tf), and adopted
# here. Inert once the client is in state; remove it in a later change.
import {
  id = "1c:f6:4c:47:5b:c6"
  to = module.unifi.unifi_client.mac4o_mini
}
