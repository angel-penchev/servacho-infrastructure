resource "unifi_radius_profile" "default" {
  name                = "Default"
  vlan_enabled        = true
  vlan_wlan_mode      = "optional"
  use_usg_auth_server = true

  auth_server {
    port   = 1812
    secret = var.radius_secret
  }
}
