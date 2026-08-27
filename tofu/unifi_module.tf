module "unifi" {
  source = "./unifi"
}

moved {
  from = unifi_network.default
  to   = module.unifi.unifi_network.default
}
moved {
  from = unifi_network.main
  to   = module.unifi.unifi_network.main
}
moved {
  from = unifi_network.guest
  to   = module.unifi.unifi_network.guest
}
moved {
  from = unifi_network.public_servers
  to   = module.unifi.unifi_network.public_servers
}
moved {
  from = unifi_network.private_servers
  to   = module.unifi.unifi_network.private_servers
}
moved {
  from = unifi_network.iot
  to   = module.unifi.unifi_network.iot
}
moved {
  from = unifi_network.qoax_community_vps
  to   = module.unifi.unifi_network.qoax_community_vps
}
moved {
  from = unifi_network.qoax_community_broadcast_vps
  to   = module.unifi.unifi_network.qoax_community_broadcast_vps
}
moved {
  from = unifi_network.fmicodes_vps
  to   = module.unifi.unifi_network.fmicodes_vps
}
