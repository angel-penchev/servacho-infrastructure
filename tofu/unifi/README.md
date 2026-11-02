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
| `ingress.tf` | one policy per tenant of the ingress VM, from `nixos/hosts/ingress/tenants.json`; created by the apply, not in the UI first (`docs/ingress.md`) | Settings → Policy Engine |
| `port_forwards.tf` | NAT port forwards | Settings → Policy Engine → NAT |
| `radius.tf` | the RADIUS user accounts | Settings → Profiles → RADIUS |
| `vpn.tf` | Teleport (documented; the provider can only read it), OpenVPN and WireGuard servers | Settings → VPN |
| `settings.tf` | site settings (`unifi_setting`), including the Global Switch Settings the provider covers (`global_switch`; the 802.1X fallback VLAN and four other keys stay hand-set) and the Gateway mDNS Proxy (`mdns`); security posture (unsupported); Etherlighting (expressible, unmanaged on purpose) | Settings → System, Settings → Networks → Global Switch Settings, Settings → Networks → Global, Control Plane → Console |
| `mdns.tf` | notes on the Gateway mDNS Proxy, which `settings.tf` manages: why Main + IoT, the excluded services and the 25-service catalogue | Settings → Networks → Global |
| `admins.tf` | the two admin accounts (unsupported, documentation only) | Admins & Users |
| `alarms.tf` | the Alarm Manager rules (unsupported, documentation only) | Alarm Manager |

## Conventions

- **`FIXME(unifi)`** — not in code at v0.65.0, expressible or not; the comment carries
  the live values so a rebuild can reproduce them (`docs/unifi-manual-vs-tofu.md` §15).
- **`FIXME(unifi-ui-only)`** — a field the UI sets that has no attribute on an otherwise
  managed resource. A from-scratch create would land on controller defaults, or on
  `false` where the provider sends a field it does not model (the port profiles'
  booleans, see `port_profiles.tf`).
- Comments explain *why* a value is what it is; dates, CI runs and the change history
  live in `docs/`, not in the code.
- Device `port_override` blocks carry `ignore_changes`: they document live, they do not
  reconcile it. The upstream array fixes they waited for have shipped (upstream #430
  and #438 in v0.56.0, #652 in v0.62.0; #470 was `unifi_port_profile`'s), but import
  and refresh never put `port_override` in state, so lifting an ignore adds every block
  unchecked. `unifi_device_port` (v0.65.0), imported one port at a time, is the way out
  once CI runs OpenTofu >= 1.12: its Update sets no resource identity, so on 1.11 every
  in-place update fails after the PUT (`docs/unifi-manual-vs-tofu.md` §14.3).

## Secrets

Never in this tree. The root module reads them from OpenBao (`secret/unifi/...`) and
passes them in as the five variables in `module.tf`; the controller credentials
themselves are consumed by the provider block in `../providers.tf`.

## Related docs

- `docs/unifi-manual-vs-tofu.md` — live-vs-code drift report and provider bug surface;
  §15 lists what is still not in code, comment by comment, and what would clear it.
- `docs/unifi-browser-changes.md` — dated log of every change made outside code.
- `docs/unifi-mgmt-vlan-99-runbook.md` — the management-VLAN migration.
- `docs/unifi-import-plan.md` — how the live controller was imported into state (2026-09-14) and how to import one more resource.
