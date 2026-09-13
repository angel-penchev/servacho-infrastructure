data "unifi_radius_profile" "default" {
  name = "Default"
}

# All four users exist on the controller and match these attributes exactly
# (verified 2026-09-13 against /rest/account: tunnel_type 13, tunnel_medium_type 6,
# vlan 2, group_policy GLOBAL). vl.penchev and v.todorova were created by hand in the
# UI, so the controller is the source of truth for their passwords.
# All four also have entries in the Vault `unifi/radius/users` secret (2026-09-13).
# TODO(import): unifi_radius_user has no allow_existing -- like every other resource on
# the rebuilt controller, these must be `tofu import`ed before an apply, or the create
# will 400 on the duplicate account name.
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
