moved {
  from = unifi_network.default
  to   = module.core.unifi_network.default
}
moved {
  from = unifi_network.main
  to   = module.core.unifi_network.main
}
moved {
  from = unifi_network.guest
  to   = module.core.unifi_network.guest
}
moved {
  from = unifi_network.public_servers
  to   = module.core.unifi_network.public_servers
}
moved {
  from = unifi_network.private_servers
  to   = module.core.unifi_network.private_servers
}
moved {
  from = unifi_network.iot
  to   = module.core.unifi_network.iot
}
moved {
  from = unifi_network.qoax_community_vps
  to   = module.core.unifi_network.qoax_community_vps
}
moved {
  from = unifi_network.qoax_community_broadcast_vps
  to   = module.core.unifi_network.qoax_community_broadcast_vps
}
moved {
  from = unifi_network.fmicodes_vps
  to   = module.core.unifi_network.fmicodes_vps
}
moved {
  from = unifi_port_profile.main
  to   = module.core.unifi_port_profile.main
}
moved {
  from = unifi_port_profile.public_servers
  to   = module.core.unifi_port_profile.public_servers
}
moved {
  from = unifi_port_profile.private_servers
  to   = module.core.unifi_port_profile.private_servers
}
moved {
  from = unifi_port_profile.iot
  to   = module.core.unifi_port_profile.iot
}
moved {
  from = unifi_wan.vivacom_primary
  to   = module.core.unifi_wan.vivacom_primary
}
moved {
  from = unifi_wan.vivacom_secondary
  to   = module.core.unifi_wan.vivacom_secondary
}
moved {
  from = unifi_firewall_zone.dmz
  to   = module.security.unifi_firewall_zone.dmz
}
moved {
  from = unifi_firewall_policy.allow_main_to_iot
  to   = module.security.unifi_firewall_policy.allow_main_to_iot
}
moved {
  from = unifi_port_forward.minecraft_server
  to   = module.security.unifi_port_forward.minecraft_server
}
moved {
  from = unifi_port_forward.nginx_proxy
  to   = module.security.unifi_port_forward.nginx_proxy
}
moved {
  from = unifi_port_forward.fmicodes_db
  to   = module.security.unifi_port_forward.fmicodes_db
}
moved {
  from = unifi_port_forward.fmicodes_ssh
  to   = module.security.unifi_port_forward.fmicodes_ssh
}
moved {
  from = unifi_port_forward.fmicodes_ssh_worker
  to   = module.security.unifi_port_forward.fmicodes_ssh_worker
}
moved {
  from = unifi_port_forward.fmicodes_intercom
  to   = module.security.unifi_port_forward.fmicodes_intercom
}
moved {
  from = unifi_radius_user.users
  to   = module.security.unifi_radius_user.users
}
moved {
  from = unifi_wlan.stkr
  to   = module.wireless.unifi_wlan.stkr
}
moved {
  from = unifi_wlan.stkr_guest
  to   = module.wireless.unifi_wlan.stkr_guest
}
moved {
  from = unifi_wlan.stkr_iot
  to   = module.wireless.unifi_wlan.stkr_iot
}
moved {
  from = unifi_client.michelangelo
  to   = module.system.unifi_client.michelangelo
}
moved {
  from = unifi_client.jetkvm
  to   = module.system.unifi_client.jetkvm
}
moved {
  from = unifi_client.sami_dev_machine
  to   = module.system.unifi_client.sami_dev_machine
}
moved {
  from = unifi_client.rpi_petacho
  to   = module.system.unifi_client.rpi_petacho
}
moved {
  from = unifi_client.networkboot_server
  to   = module.system.unifi_client.networkboot_server
}
moved {
  from = unifi_client.tsb_mint
  to   = module.system.unifi_client.tsb_mint
}
moved {
  from = unifi_client.djam_11
  to   = module.system.unifi_client.djam_11
}
moved {
  from = unifi_client.nixos
  to   = module.system.unifi_client.nixos
}
moved {
  from = unifi_client.minecraft_fabric_server
  to   = module.system.unifi_client.minecraft_fabric_server
}
moved {
  from = unifi_setting.default
  to   = module.system.unifi_setting.default
}
moved {
  from = unifi_vpn_server.wireguard
  to   = module.system.unifi_vpn_server.wireguard
}
