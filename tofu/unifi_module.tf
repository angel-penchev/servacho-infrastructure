module "unifi" {
  source = "./unifi"

  radius_profile_secret  = data.vault_kv_secret_v2.radius_profile.data["secret"]
  radius_users_passwords = data.vault_kv_secret_v2.radius_users.data
}
