# One-time import of every live UniFi object into state (docs/unifi-import-plan.md).
#
# Live ids read from the controller on 2026-09-14. Addresses are the flat module's
# (module.unifi.<type>.<name>). Run `tofu plan` here to see the 46 imports plus any
# drift, then apply; afterwards delete this file (see ../vms.tf for the same pattern).
# Formats per resource type are from the provider's ImportState code at v0.55.0.

# Networks (networks.tf) -- controller _id
import {
  to = module.unifi.unifi_network.default
  id = "6a9c2f5583de4db1f0f1dcf6"
}
import {
  to = module.unifi.unifi_network.unifi_devices
  id = "6aa6e779e5a2f2ebb4473ca6"
}
import {
  to = module.unifi.unifi_network.main
  id = "6a9d34cc3346f05e9f31efd9"
}
import {
  to = module.unifi.unifi_network.guest
  id = "6a9d34da3346f05e9f31efe6"
}
import {
  to = module.unifi.unifi_network.public_servers
  id = "6a9d35773346f05e9f31f0ac"
}
import {
  to = module.unifi.unifi_network.private_servers
  id = "6a9d358b3346f05e9f31f0bd"
}
import {
  to = module.unifi.unifi_network.iot
  id = "6a9d35a43346f05e9f31f0db"
}
import {
  to = module.unifi.unifi_network.qoax_community_vps
  id = "6a9d35e63346f05e9f31f11f"
}
import {
  to = module.unifi.unifi_network.fmicodes_vps
  id = "6a9d360a3346f05e9f31f145"
}

# WANs (wans.tf) -- a bare 24-hex value is taken as the _id, anything else as the WAN name
import {
  to = module.unifi.unifi_wan.vivacom_primary
  id = "6a9c2f5583de4db1f0f1dcf4"
}
import {
  to = module.unifi.unifi_wan.vivacom_secondary
  id = "6a9c2f5583de4db1f0f1dcf5"
}

# VPN servers (vpn.tf) -- _id of the remote-user-vpn networkconf
import {
  to = module.unifi.unifi_vpn_server.openvpn
  id = "6aa6f9cae5a2f2ebb4474a26"
}
import {
  to = module.unifi.unifi_vpn_server.wireguard
  id = "6aa70407e5a2f2ebb44756e8"
}

# Port profiles (port_profiles.tf) -- _id
import {
  to = module.unifi.unifi_port_profile.unifi_devices
  id = "6a9d116e3346f05e9f31cd55"
}
import {
  to = module.unifi.unifi_port_profile.host_device
  id = "6a9e48d140324b44914391ab"
}
import {
  to = module.unifi.unifi_port_profile.public_servers
  id = "6aa12b2a40324b449145290b"
}
import {
  to = module.unifi.unifi_port_profile.private_servers
  id = "6aa12ba440324b449145295b"
}
import {
  to = module.unifi.unifi_port_profile.iot
  id = "6aa12c4e40324b44914529f2"
}

# Devices (device_*.tf) -- MAC (the provider resolves it to the _id; site comes from the provider)
import {
  to = module.unifi.unifi_device.udm_pro_max
  id = "28:70:4e:5c:b4:b2"
}
import {
  to = module.unifi.unifi_device.usw_pro_max_24_poe
  id = "9c:05:d6:e2:6b:1d"
}
import {
  to = module.unifi.unifi_device.usw_aggregation
  id = "1c:6a:1b:98:38:ee"
}
import {
  to = module.unifi.unifi_device.u7_pro_living_room
  id = "9c:05:d6:d9:ad:79"
}
import {
  to = module.unifi.unifi_device.u7_pro_bedroom
  id = "9c:05:d6:d9:af:65"
}

# Fixed-IP clients (clients.tf) -- MAC only, the provider rejects anything without colons
import {
  to = module.unifi.unifi_client.servacho_gosho
  id = "38:05:25:30:79:97"
}
import {
  to = module.unifi.unifi_client.jetkvm_servacho_gosho
  id = "30:52:53:0a:09:87"
}
import {
  to = module.unifi.unifi_client.jetkvm_michelangelo
  id = "30:52:53:0d:1a:68"
}
import {
  to = module.unifi.unifi_client.fmicodes_master_node
  id = "bc:24:11:c3:e5:f4"
}
import {
  to = module.unifi.unifi_client.fmicodes_worker_node_1
  id = "bc:24:11:23:76:b5"
}
import {
  to = module.unifi.unifi_client.hackjamhub_intercom
  id = "bc:24:11:8a:b7:98"
}
import {
  to = module.unifi.unifi_client.living_room_tv
  id = "b0:b3:69:41:2c:9b"
}
import {
  to = module.unifi.unifi_client.bedroom_tv
  id = "f4:4e:b4:73:bf:19"
}

# WLANs (wlans.tf) -- _id
import {
  to = module.unifi.unifi_wlan.stkr
  id = "6a9d0ff73346f05e9f31cb74"
}
import {
  to = module.unifi.unifi_wlan.stkr_guest
  id = "6a9e4cee40324b4491439ecb"
}
import {
  to = module.unifi.unifi_wlan.stkr_iot
  id = "6a9f205b40324b44914417d1"
}
import {
  to = module.unifi.unifi_wlan.stkr_iot_2_4ghz
  id = "6a9f207640324b44914417fa"
}

# Firewall zones (firewall.tf) -- _id; Dmz/Hotspot are built-in, IoT is custom
import {
  to = module.unifi.unifi_firewall_zone.dmz
  id = "6a9d37ad3346f05e9f31f329"
}
import {
  to = module.unifi.unifi_firewall_zone.hotspot
  id = "6a9d37ad3346f05e9f31f328"
}
import {
  to = module.unifi.unifi_firewall_zone.iot
  id = "6aa12f7b40324b4491452cf5"
}

# Firewall policies (firewall.tf) -- _id (v2 API objects)
import {
  to = module.unifi.unifi_firewall_policy.allow_main_to_iot
  id = "6a9f35ba40324b4491442e21"
}
import {
  to = module.unifi.unifi_firewall_policy.allow_private_servers_to_iot
  id = "6aa130b640324b4491452eb5"
}

# Port forward (port_forwards.tf) -- _id
import {
  to = module.unifi.unifi_port_forward.nginx_proxy
  id = "6a9d909b40324b44914265d2"
}

# RADIUS users (radius.tf) -- account _id; the only type with no allow_existing
import {
  to = module.unifi.unifi_radius_user.users["a.penchev"]
  id = "6a9d366c3346f05e9f31f1ba"
}
import {
  to = module.unifi.unifi_radius_user.users["e.pencheva"]
  id = "6a9f24ec40324b4491441d6d"
}
import {
  to = module.unifi.unifi_radius_user.users["vl.penchev"]
  id = "6aa6b995e5a2f2ebb44715bb"
}
import {
  to = module.unifi.unifi_radius_user.users["v.todorova"]
  id = "6aa6b982e5a2f2ebb44715ab"
}

# Site settings (settings.tf) -- the site name; populates nothing until the first refresh
import {
  to = module.unifi.unifi_setting.default
  id = "default"
}
