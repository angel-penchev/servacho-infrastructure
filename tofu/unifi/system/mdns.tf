# ----------------------------------------------------------------------------
# Gateway mDNS Proxy
#
# Nothing is declared here on purpose -- the setting is not expressible in code. It is
# recorded where someone would look for it.
#
# Live (verified 2026-09-09): mode = "all", enabled_for = "all", both service lists
# empty. Every service reflected across every network, Guest included; the Custom picker
# lists Guest (3) as eligible, so guest networks are not excluded from the reflector.
#
# Decision: leave it on Auto/all. Narrowing to `custom` with Guest explicitly scoped in
# is optional hardening. Note that mDNS was never the cause of the Guest casting failure
# -- see the abandoned-Guest-access note in ../security/firewall.tf.
#
# FIXME(unifi): managing this needs changes in BOTH upstream repos:
#
#   1. go-unifi -- `settings.Mdns` declares only `mode`, `predefined_services` and
#      `custom_services`. The `enabled_for` / `enabled_for_network_ids` fields the
#      controller uses for per-network scoping are missing, so a round-trip drops them.
#   2. terraform-provider-unifi -- no mdns block on `unifi_setting`, on v0.55.0 or main.
#
#   Action: go-unifi PR first, then the provider PR against it -- the same two-repo shape
#   as our #463 and #470.
#
# The `unifi_setting_mdns` block that used to sit here was fiction: the resource has
# never existed and its attributes were invented. Do not restore it from git history.
#
# Related: the per-network `multicast_dns` flag in ../core/networks.tf is a different,
# cosmetic setting that UniFi OS gateways ignore (upstream #282).
# ----------------------------------------------------------------------------
