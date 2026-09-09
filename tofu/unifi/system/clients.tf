# ----------------------------------------------------------------------------
# Fixed-IP clients
#
# Deliberately empty. Every `unifi_client` resource that used to live here was
# removed on 2026-09-09 because none of them matched a fixed-IP reservation on the
# controller -- in fact the controller has never seen any of their MAC addresses.
# The 2026-09 factory reset wiped the client database, and the ten entries here had
# been accumulating drift for long enough that not one survived the check.
#
# Removed (all ten), with what the controller actually knows about each MAC:
#
#   michelangelo             34:5a:60:7a:62:05  192.168.2.178  MAC unknown to controller
#   jetkvm                   30:52:53:08:45:16  192.168.5.21   MAC unknown to controller
#   sami_dev_machine         bc:24:11:b0:83:56  192.168.4.32   MAC unknown to controller
#   rpi_petacho              2c:cf:67:33:a5:49  192.168.4.20   MAC unknown to controller
#   networkboot_server       bc:24:11:9f:f8:56  192.168.5.31   MAC unknown to controller
#   tsb_mint                 00:00:c4:54:44:f9  192.168.4.15   MAC unknown to controller
#   djam_11                  00:e0:5c:36:1b:41  192.168.4.10   MAC unknown to controller
#   nixos                    bc:24:11:75:a0:71  192.168.4.228  MAC unknown to controller
#   minecraft_fabric_server  bc:24:11:90:56:95  192.168.4.25   MAC unknown to controller
#   servacho_gosho_jetkvm    30:52:53:0a:09:87  192.168.5.20   device EXISTS (Pro Max port
#                                                              12) but has no reservation --
#                                                              it is on DHCP at 192.168.1.127
#
# The MAC on that last one was corrected from `38:52:53:0a:09:87` to
# `30:52:53:0a:09:87` in the commit immediately before this one; the resource is still
# removed, because `192.168.5.20` is not a configured static IP on the controller.
#
# Removal is safe with respect to state: none of these clients exist on the
# controller, so there is nothing for a destroy to act on.
#
# ----------------------------------------------------------------------------
# The seven fixed-IP reservations that DO exist on the controller (2026-09-09)
#
#   192.168.5.10   38:05:25:30:79:97  (unnamed)
#   192.168.5.23   30:52:53:0d:1a:68  jetkvm-ce4ac3437e0d935d
#   192.168.5.200  bc:24:11:c3:e5:f4  fmicodes-master-node
#   192.168.5.201  bc:24:11:23:76:b5  fmicodes-worker-node-1
#   192.168.5.215  bc:24:11:8a:b7:98  hackjamhub-intercom
#   192.168.6.10   b0:b3:69:41:2c:9b  Living Room TV   (EON box, wired Pro Max port 6)
#   192.168.6.11   52:4b:e7:7b:a6:c7  Bedroom TV       (Sony BRAVIA, Wi-Fi StKr_IoT)
#
# None of them carry a `network_id`: the reservations are not bound to a network, the
# port profile or WLAN decides the VLAN and the reservation only pins the address.
#
# FIXME(unifi): these are NOT declared as resources on purpose. Every in-place
# `unifi_client` update fails at v0.55.0 with
# `Provider produced inconsistent result after apply: .last_ip` -- `last_ip` and
# `hostname` use UseStateForUnknown, which pins the planned value to prior state while
# the controller legitimately reports a different one between plan and apply (lease
# renewal, re-association). Upstream #428, merged as #447, still unreleased. Clearing
# `fixed_ip` is likewise unreleased (#400).
#
# Declaring them today would mean adopting existing clients with `allow_existing`, and
# the first apply that touched one would fail. Revisit after v0.56.0 ships; until then
# the reservations are managed in the admin panel and logged in
# docs/unifi-browser-changes.md. See also 14.5 of docs/unifi-manual-vs-tofu.md.
#
# TODO(jetkvm-port-12): `jetkvm-4562a8bf464c58c8` (30:52:53:0a:09:87) sits on Pro Max
# port 12 with no port override, so it lands on the untagged UniFi Devices VLAN at
# 192.168.1.127. The removed resource wanted it on Private Servers at 192.168.5.20,
# which is the same intent as its sibling on port 18 (now 192.168.5.23). Decide whether
# to apply the `Private Server` port profile to port 12 and reserve .5.20 -- see 3.4 of
# docs/unifi-manual-vs-tofu.md.
# ----------------------------------------------------------------------------
