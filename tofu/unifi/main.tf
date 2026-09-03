module "devices" {
  source = "./devices"

  network_default_id              = module.core.network_default_id
  network_public_servers_id       = module.core.network_public_servers_id
  port_profile_main_id            = module.core.port_profile_main_id
  port_profile_iot_id             = module.core.port_profile_iot_id
  port_profile_public_servers_id  = module.core.port_profile_public_servers_id
  port_profile_private_servers_id = module.core.port_profile_private_servers_id
  wan_primary_id                  = module.core.wan_vivacom_primary_id
  wan_secondary_id                = module.core.wan_vivacom_secondary_id
}

module "core" {
  source = "./core"
}

module "security" {
  source = "./security"

  network_main_id           = module.core.network_main_id
  network_iot_id            = module.core.network_iot_id
  network_public_servers_id = module.core.network_public_servers_id
  radius_users_passwords    = var.radius_users_passwords
}

module "wireless" {
  source = "./wireless"

  network_main_id       = module.core.network_main_id
  network_guest_id      = module.core.network_guest_id
  network_iot_id        = module.core.network_iot_id
  wlan_guest_passphrase = var.wlan_guest_passphrase
  wlan_iot_passphrase   = var.wlan_iot_passphrase
}

module "system" {
  source = "./system"

  network_main_id            = module.core.network_main_id
  network_guest_id           = module.core.network_guest_id
  network_private_servers_id = module.core.network_private_servers_id
  network_public_servers_id  = module.core.network_public_servers_id
  wireguard_private_key      = var.wireguard_private_key
}
