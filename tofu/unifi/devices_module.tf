module "devices" {
  source = "./devices"

  network_default_id              = unifi_network.default.id
  network_public_servers_id       = unifi_network.public_servers.id
  port_profile_main_id            = unifi_port_profile.main.id
  port_profile_iot_id             = unifi_port_profile.iot.id
  port_profile_public_servers_id  = unifi_port_profile.public_servers.id
  port_profile_private_servers_id = unifi_port_profile.private_servers.id
  wan_primary_id                  = unifi_wan.vivacom_primary.id
  wan_secondary_id                = unifi_wan.vivacom_secondary.id
}
