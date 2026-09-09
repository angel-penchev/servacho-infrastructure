# ----------------------------------------------------------------------------
# Gateway mDNS Proxy
#
# Nothing is declared in this file on purpose -- the setting is not expressible in
# code at any level. It is recorded here rather than left out so the gap is visible
# where someone would look for it.
#
# Live state on the controller (Network 10.6.101, verified 2026-09-09):
#
#   mode:                     "all"     # all | auto | custom
#   enabled_for:              "all"
#   enabled_for_network_ids:  []        # empty because enabled_for is "all"
#   predefined_services:      []
#   custom_services:          []
#
# That is the most permissive setting there is: every service reflected across every
# network, Guest included. It is what lets a Guest phone discover the two living-room
# and bedroom TVs; the unicast permission to actually stream to them is a separate
# thing and lives in ../security/firewall.tf
# (`unifi_firewall_policy.allow_guest_to_tvs`).
#
# Decision (2026-09-09): leave it on Auto/all. Casting works, and narrowing it to
# `custom` with Guest explicitly scoped in is optional hardening, not a fix.
#
# FIXME(unifi): managing this needs changes in BOTH upstream repos, so a
# provider-only patch is not enough:
#
#   1. ubiquiti-community/go-unifi -- `unifi/settings/mdns.generated.go` declares
#      `settings.Mdns` with only `mode`, `predefined_services` and `custom_services`.
#      The `enabled_for` and `enabled_for_network_ids` fields the controller actually
#      uses for per-network scoping are missing entirely, so the round-trip would drop
#      them. Generator input needs the fields added first.
#   2. ubiquiti-community/terraform-provider-unifi -- there is no mdns block on
#      `unifi_setting`, on v0.55.0 (our pin) or on `main`. Needs adding once go-unifi
#      carries the fields.
#
#   Action: open the go-unifi PR first, then the provider PR against it -- the same
#   two-repo shape as our #463 and #470.
#
# The block that used to sit here was fiction and has been deleted: `unifi_setting_mdns`
# has never existed in any provider release, its `vlan_scope` / `service_scope` /
# `services` attributes were invented, and it referenced a `var.network_iot_id` that is
# not even declared in this module -- so it could never have planned, let alone applied.
# Do not restore it from git history.
#
# Related: the per-network `multicast_dns` flag in ../core/networks.tf is a different,
# cosmetic setting -- UniFi OS gateways ignore it (upstream #282). This site-wide proxy
# is what is actually in force.
# ----------------------------------------------------------------------------
