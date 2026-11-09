# SUGAMING VPS was created on the controller first (docs/unifi-browser-changes.md)
# and is adopted here. Both blocks are inert once applied; remove them in a
# later change.
import {
  id = "6af1576ff1a8a0e9ad974ee7"
  to = module.unifi.unifi_network.sugaming_vps
}

# VLAN 12 keeps its controller object; only its name changed.
moved {
  from = module.unifi.unifi_network.fmicodes_vps
  to   = module.unifi.unifi_network.qoax_public_servers
}
