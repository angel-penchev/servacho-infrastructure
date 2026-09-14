# UniFi (UDM StKr) — OpenTofu module

One controller, one site, mirrored resource by resource. **The controller is the source
of truth**: change things in the UI (or its API), read them back, mirror them here, and
log the change in `docs/unifi-browser-changes.md`. Everything live is imported and the
plan must stay clean; `tofu apply` runs from CI (status, history and provider caveats:
`docs/unifi-manual-vs-tofu.md`).

## Layout

A single flat module. No submodules: nothing is instantiated twice, so resources
reference each other directly (`unifi_network.iot.id`) instead of through
output → variable plumbing. One topic per file:

| File | Contents | Where it lives in the UI |
|---|---|---|
| `module.tf` | provider pin, the five secret inputs, shared data sources | — |
| `networks.tf` | the nine LAN networks / VLANs (incl. the VLAN 99 management network) | Settings → Networks |
| `wans.tf` | the two Vivacom uplinks; WAN SLA block (unsupported) | Settings → Internet |
| `port_profiles.tf` | the five switch-port profiles (UniFi Device, Host Device, per-VLAN) | Settings → Profiles → Ethernet Ports |
| `device_udm_pro_max.tf` | the gateway: name, port overrides | Devices |
| `device_usw_pro_max_24_poe.tf` | the access switch: management IP, port overrides | Devices |
| `device_usw_aggregation.tf` | the aggregation switch | Devices |
| `device_u7_pro_living_room.tf`, `device_u7_pro_bedroom.tf` | the two APs | Devices |
| `clients.tf` | fixed-IP reservations | Clients |
| `wlans.tf` | the four SSIDs | Settings → WiFi |
| `firewall.tf` | zones (Dmz, Hotspot) and policies | Settings → Policy Engine |
| `port_forwards.tf` | NAT port forwards | Settings → Policy Engine → NAT |
| `radius.tf` | the RADIUS user accounts | Settings → Profiles → RADIUS |
| `vpn.tf` | Teleport (documented), OpenVPN and WireGuard servers | Settings → VPN |
| `settings.tf` | site settings (`unifi_setting`), plus unsupported blocks: switch/802.1X, security posture, ether lighting | Settings → System, Control Plane → Console |
| `mdns.tf` | the Gateway mDNS Proxy configuration (unsupported by the provider, applied by hand) | Settings → Networks → Global |
| `admins.tf` | the two admin accounts (unsupported, documentation only) | Admins & Users |
| `alarms.tf` | the Alarm Manager rules (unsupported, documentation only) | Alarm Manager |

## Conventions

- **`FIXME(unifi)`** — the provider (v0.55.0) cannot express this at all. The comment
  carries the live values so a rebuild can reproduce them by hand.
- **`FIXME(unifi-ui-only)`** — a field the UI sets that has no attribute on an otherwise
  managed resource. A from-scratch create would land on controller defaults.
- Comments explain *why* a value is what it is; dates, CI runs and the change history
  live in `docs/`, not in the code.
- Device `port_override` blocks carry `ignore_changes` until the upstream array-handling
  bugs land (#430/#438/#470); they document live, they do not reconcile it.

## Secrets

Never in this tree. The root module reads them from OpenBao (`secret/unifi/...`) and
passes them in as the five variables in `module.tf`; the controller credentials
themselves are consumed by the provider block in `../providers.tf`.

## Related docs

- `docs/unifi-manual-vs-tofu.md` — live-vs-code drift report and provider bug surface.
- `docs/unifi-browser-changes.md` — dated log of every change made outside code.
- `docs/unifi-mgmt-vlan-99-runbook.md` — the management-VLAN migration.
- `docs/unifi-import-plan.md` — how the live controller was imported into state (2026-09-14) and how to import one more resource.
