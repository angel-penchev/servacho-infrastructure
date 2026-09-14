# Controller admin accounts (Admins & Users). Documentation only.
#
# FIXME(unifi): admins are UniFi OS users and the provider has no admin resource
#   (`unifi_account` is RADIUS, `unifi_client` a network client). Both accounts are
#   created by hand. Live (`/proxy/network/api/stat/admin`):
#
#   1. Owner -- the human owner's UI account. is_owner, is_super, site admin.
#   2. servacho-managment-plane (sic) -- the tofu service account. Local admin, no UI
#      account, no 2FA; is_super, site admin. Credentials: OpenBao secret/unifi ->
#      username, password, consumed by the provider block in ../providers.tf.
#      A factory reset wipes it; recreate it by hand before anything else.
#
#   If the provider ever gains an admin resource, import this one first -- nothing
#   else in this tree can be applied without it.
