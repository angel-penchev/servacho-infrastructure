module "unifi" {
  source = "./unifi"

  radius_secret = data.vault_kv_secret_v2.unifi_credentials.data["radius_secret"]
}
