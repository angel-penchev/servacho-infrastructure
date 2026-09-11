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
# network, Guest included. The UI tooltip for Auto says so outright -- "Automatically
# allows all services across all VLANs" -- and the Custom picker lists Guest (3) as an
# eligible VLAN, so guest networks are not excluded from the reflector.
#
# Decision (2026-09-09, reaffirmed 2026-09-11): leave it on Auto/all, and note that
# **mDNS was never the cause of anything.** When Guest clients could not see the TVs as
# cast targets, the reflector was measurably working the whole time: 337,966 hits on the
# predefined `Hotspot -> Gateway: Allow mDNS` policy and 127,493 on `IoT -> Gateway:
# Allow mDNS`, both ticking over in real time. The actual cause was `l2_isolation`
# (Client Device Isolation) on the StKr_Guest WLAN dropping the reflected multicast at
# the access point. See the abandoned-Guest-access note in ../security/firewall.tf.
#
# Narrowing this to `custom` with Guest explicitly scoped in remains optional hardening.
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
