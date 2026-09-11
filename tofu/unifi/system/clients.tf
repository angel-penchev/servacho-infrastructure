# ----------------------------------------------------------------------------
# Fixed-IP clients
#
# Deliberately empty. The ten `unifi_client` resources that used to live here were
# removed on 2026-09-09: the 2026-09 factory reset wiped the client database and not one
# of their MACs is known to the controller any more, so there was nothing for a destroy
# to act on either. See the commit history for the list.
#
# The seven fixed-IP reservations that DO exist on the controller (2026-09-10):
#
#   192.168.5.10   38:05:25:30:79:97  (unnamed)
#   192.168.5.23   30:52:53:0d:1a:68  jetkvm-ce4ac3437e0d935d
#   192.168.5.200  bc:24:11:c3:e5:f4  fmicodes-master-node
#   192.168.5.201  bc:24:11:23:76:b5  fmicodes-worker-node-1
#   192.168.5.215  bc:24:11:8a:b7:98  hackjamhub-intercom
#   192.168.6.10   b0:b3:69:41:2c:9b  Living Room TV  (EON box, wired Pro Max port 6)
#   192.168.6.11   f4:4e:b4:73:bf:19  Bedroom TV      (Sony BRAVIA, Wi-Fi StKr_IoT)
#
# None carry a `network_id`: the port profile or WLAN decides the VLAN, the reservation
# only pins the address.
#
# FIXME(unifi): these are NOT declared as resources on purpose. Every in-place
# `unifi_client` update fails at v0.55.0 with `inconsistent result after apply: .last_ip`
# -- `last_ip` and `hostname` use UseStateForUnknown, pinning the planned value to prior
# state while the controller legitimately reports a different one between plan and apply.
# Upstream #428, merged as #447, still unreleased; clearing `fixed_ip` likewise (#400).
# Declaring them today means adopting with `allow_existing`, and the first apply that
# touched one would fail. Revisit after v0.56.0. Until then they are managed in the admin
# panel and logged in docs/unifi-browser-changes.md.
#
# TODO(jetkvm-port-12): `jetkvm-4562a8bf464c58c8` (30:52:53:0a:09:87) sits on Pro Max
# port 12 with no port override, so it lands on the untagged UniFi Devices VLAN at
# 192.168.1.127. The removed resource wanted it on Private Servers at 192.168.5.20, the
# same intent as its sibling on port 18. Decide whether to apply the `Private Server`
# profile to port 12 and reserve .5.20 -- see 3.4 of docs/unifi-manual-vs-tofu.md.
# ----------------------------------------------------------------------------
