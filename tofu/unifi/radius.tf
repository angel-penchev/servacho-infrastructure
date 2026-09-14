# Passwords in OpenBao secret/unifi/radius/users. VLAN 2 = Main, the network an
# authenticated 802.1X client is placed on.
# FIXME(unifi): unifi_radius_user has no allow_existing -- a user created by hand must be
#   imported before it is declared, or the create 400s on the duplicate name.
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
