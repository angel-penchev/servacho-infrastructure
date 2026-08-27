module "unifi" {
  source = "./unifi"

  radius_profile_secret  = data.vault_kv_secret_v2.radius_profile.data["secret"]
  radius_users_passwords = data.vault_kv_secret_v2.radius_users.data
  wlan_guest_passphrase  = data.vault_kv_secret_v2.wlan_passphrases.data["guest"]
  wlan_iot_passphrase    = data.vault_kv_secret_v2.wlan_passphrases.data["iot"]
}
