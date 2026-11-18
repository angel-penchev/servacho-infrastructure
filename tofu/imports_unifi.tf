# The SUGAMING plane's client was named and given its fixed IP on the
# controller first (docs/unifi-browser-changes.md) and is adopted here by MAC.
# The block is inert once applied; remove it in a later change.
import {
  id = "bc:24:11:85:1b:83"
  to = module.unifi.unifi_client.sugaming_management_plane
}
