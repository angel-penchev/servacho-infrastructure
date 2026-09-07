data "unifi_radius_profile" "default" {
  name = "Default"
}

# TODO(radius-users): vl.penchev and v.todorova do not exist on the controller yet
# and will be created manually. They are declared here so the intent is recorded, but
# an apply will fail on the var.radius_users_passwords lookup until both have entries
# in the Vault `unifi/radius/users` secret.
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
