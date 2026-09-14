# ----------------------------------------------------------------------------
# Controller admin accounts
#
# FIXME(unifi): not expressible at provider v0.55.0. Admins are UniFi OS users
# (Network app: Admins & Users, `/api/stat/admin`), and the provider has no admin/user
# resource -- `unifi_account` is a RADIUS account, `unifi_client` a network client.
# Documented here so the dependency is visible; both accounts are created by hand.
#
# Live, verified 2026-09-13 (`/proxy/network/api/stat/admin`):
#
#   1. Owner            -- the human owner (UI account), is_owner true, is_super true,
#                          site "default" role admin.
#   2. servacho-managment-plane  (sic, controller spelling)
#                       -- the tofu / management-plane service account. Local admin
#                          (no UI account, no 2FA), is_owner false, is_super true, site
#                          "default" role admin. Credentials: OpenBao
#                          `secret/unifi` -> `username`, `password`, consumed by the
#                          provider block in ../providers.tf. Recreated by hand on
#                          2026-09-13 after the factory reset wiped it; login verified
#                          from the shell the same day.
#
# If the provider ever gains an admin resource, this is the one to import first --
# nothing else in this tree can be applied without it.
# ----------------------------------------------------------------------------
