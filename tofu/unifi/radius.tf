resource "unifi_radius_profile" "default" {
  name                = "Default"
  vlan_enabled        = true
  vlan_wlan_mode      = "optional"
  use_usg_auth_server = true

  lifecycle {
    ignore_changes = all
  }

  auth_server {
    port   = 1812
    secret = var.radius_profile_secret
  }
}

locals {
  radius_users = {
    "a.penchev"  = { tunnel_type = 13, tunnel_medium_type = 6, vlan = 2 }
    "e.pencheva" = { tunnel_type = 13, tunnel_medium_type = 6, vlan = 2 }
    "vl.penchev" = { tunnel_type = 13, tunnel_medium_type = 6, vlan = 2 }
    "v.todorova" = { tunnel_type = 13, tunnel_medium_type = 6, vlan = 2 }
  }
}

resource "unifi_radius_user" "users" {
  for_each = local.radius_users

  name               = each.key
  password           = var.radius_users_passwords[each.key]
  tunnel_type        = each.value.tunnel_type
  tunnel_medium_type = each.value.tunnel_medium_type
  vlan               = each.value.vlan
}
