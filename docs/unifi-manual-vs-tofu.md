# UniFi: manual rebuild vs. OpenTofu config — drift report

**Date:** 2026-09-08 (drift analysis) · **Updated:** 2026-09-08 (first remediation pass) · 2026-09-13 (RADIUS users verified in sync; mDNS scoped to Main + IoT; per-VLAN port profiles recreated; all port overrides aligned live and in code, UI-only fields marked FIXME)
**Branch:** `feat/unifi-port-config`
**Companion:** [`unifi-browser-changes.md`](unifi-browser-changes.md) — everything changed on the live controller
**Sources:** the manual rebuild checklist, the live controller (`https://192.168.1.1`, read via the Network app REST API), and `tofu/unifi/**/*.tf` as of the current working tree.

State lives on the management plane, so `tofu plan` was not run. Everything below is a three-way comparison: **checklist** (what you wrote down) vs. **live** (what the controller actually has) vs. **tofu** (what the code declares).

---

## 0. TL;DR

**Status key:** ✅ resolved · 🔧 partly resolved · ⏳ TODO · 🚫 blocked on provider

| Area | Verdict |
|---|---|
| Networks / VLANs | ✅ VLAN layout fixed in code; **mDNS decided and applied live 2026-09-13** (Custom, Main + IoT, 19 services) — per-network flags now match live |
| Port profiles | ✅ All five profiles live and matching code (per-VLAN trio recreated by hand 2026-09-13); 802.1X DHCP problem **fixed live** |
| Device names & IPs | ✅ Code matches live incl. static IPs and LEDs; `config_network` is read-only in practice until v0.56.0 (no-op plan while live matches — **not** an apply failure, correction 2026-09-13) |
| Port overrides | ✅ **All three devices aligned 2026-09-13** — live changed to the code's intent and code rewritten to the stored shape (§3.2–§3.4); every provider-expressible field declared, every UI-only field carries a `FIXME(unifi-ui-only)`. Still 🚫 not reconcilable by apply (§14.3) |
| WANs | ✅ Code now reflects live |
| Wireless | ✅ All 3 diffs applied to the live controller from code |
| RADIUS / 802.1X | 🔧 Secret now wired into `unifi_setting.radius`; global 802.1X 🚫 not expressible; **all 4 users ✅ live, matching code, and in Vault (2026-09-13)** |
| Firewall | ✅ Hotspot zone + `Dmz` casing in code; policy **created live** |
| Port forwards | ✅ Code reduced to the one live rule (`NGINX Server` → `192.168.5.58`), 2026-09-13 |
| Fixed-IP clients | ✅ `system/clients.tf` mirrors the 8 live reservations, attribute-exact, **all named** (2026-09-13); in-place updates still 🚫 blocked (§14.5) so keep it mirroring live |
| VPN | ✅ Teleport (UI-only, FIXME) + OpenVPN + WireGuard live and mirrored 2026-09-13; WireGuard peers still to add (§10) |
| Site settings | 🔧 `mgmt` + `lcm` blocks added from the Console page 2026-09-13; UniFi OS-only items carry `FIXME(unifi)`; auto speedtest decision pending (§11) |
| **Provider bugs** | **See §14 — the binding constraint. Several diffs above cannot be fixed on the pinned version, and two things already in the tree are guaranteed apply failures** |

> **Read §14 before acting on any of this.** `ubiquiti-community/unifi` v0.55.0 (2026-07-10) is still the latest release, `main` is ~88 commits and 13 unreleased fixes ahead, and the device-update code path silently drops most configured fields. That determines which of the differences below are worth fixing today.

---

## 0.5 Remediation pass — 2026-09-08

### Changed in code (needs `tofu apply` from the management plane)

| File | Change |
|---|---|
| `core/networks.tf` | `default` → name **UniFi Devices**; Qoax widened to **`192.168.10.1/23`**, renamed **Qoax VPS**, DHCP `.10.11–.11.254`; **VLAN 11 network deleted**; `TODO(mdns)` markers added; `TODO(vlan1)` note |
| `core/outputs.tf` | dropped the VLAN 11 output; `port_profile_main_id` → `port_profile_host_device_id` |
| `core/port_profiles.tf` | `unifi_devices` → name **UniFi Device**, `dot1x_ctrl` → `force_authorized`; `main` → resource **`host_device`**, name **Host Device**, native → **Main**, `stp_port_mode` → `true`, `setting_preference` → `manual`; the other three profiles kept behind a `TODO(port-profiles)` banner |
| `core/wans.tf` | primary `weight` 50 → **99**; secondary: dropped `weight` and `provider_capabilities` to match live |
| `devices/udm_pro_max.tf` | name → **UDM StKr** |
| `devices/usw_pro_max_24_poe.tf` | `config_network` dhcp → **static 192.168.1.2** |
| `devices/usw_aggregation.tf` | added `config_network` **static 192.168.1.3** |
| `devices/u7_pro_living_room.tf` | **static 192.168.1.4**, `led_override = "off"`; stale offline-AP FIXME rewritten |
| `devices/u7_pro_bedroom.tf` | **static 192.168.1.5**, `led_override = "off"` |
| `devices/*.tf` | `TODO(port-overrides)` banner on all three, incl. the `forward = "disabled"` correction |
| `devices/variables.tf`, `main.tf` | dead `network_default_id` removed; `host_device` rename plumbed; `radius_profile_secret` wired into the `system` module |
| `system/settings.tf` | added `radius = { secret = var.radius_profile_secret, … }`; refreshed the Global Switch Settings note with the 2026-09-08 re-check and the fallback-VLAN dependency |
| `system/variables.tf` | accepts `radius_profile_secret` |
| `security/firewall.tf` | `"DMZ"` → **`"Dmz"`**; added **`unifi_firewall_zone.hotspot`** ← Guest; ordering caveat noted on the policy |
| `security/variables.tf` | accepts `network_guest_id` |
| `security/radius.tf` | `TODO(radius-users)` for `vl.penchev` / `v.todorova` |

`tofu fmt` clean, `tofu validate` passes.

### Changed on the live controller

Six changes — see [`unifi-browser-changes.md`](unifi-browser-changes.md) for the full log. Headline: **the 802.1X fallback VLAN was empty, which is why unauthenticated clients got no DHCP.** It is now Guest.

### Still open

| Item | Why |
|---|---|
| ~~mDNS policy (§1, §11)~~ | ✅ **Resolved 2026-09-13.** Gateway mDNS Proxy set to Custom / Main + IoT / 19 services (manual runbook item, `system/mdns.tf`); `core/networks.tf` flags now mirror live |
| ~~The other 3 port profiles (§2)~~ | ✅ **Recreated live 2026-09-13** as `Public Server`, `Private Server`, `IoT Device`; code aligned (names, `setting_preference = manual`, `stp_port_mode = true`). Assigning ports to them is the port-override work |
| Port overrides (§3.2–§3.4) | ✅ all three devices mirrored 2026-09-13; still 🚫 inert under `ignore_changes` (§14.3) |
| ~~**Pro Max ports 6 and 18**~~ | ✅ **Assigned live by the user 2026-09-13** (6 → IoT Device, 18 → Private Server, both clients now hold their fixed IPs); code mirrors live. **Port 12** set live via the API the same day: Private Server + fixed `192.168.5.20` — all three now match code |
| RADIUS users `vl.penchev`, `v.todorova` (§6.3) | ✅ **Created live 2026-09-13, verified identical to code.** Vault `unifi/radius/users` entries confirmed. Only the `tofu import` of the four live accounts remains (see §6.3) |
| ~~Port forwards (§8)~~ | ✅ resolved 2026-09-13 — code mirrors the single live rule; fmicodes SSH/Postgres forwards and the two `count = 0` placeholders dropped |
| ~~Fixed-IP clients (§9)~~ | ✅ resolved 2026-09-13 — `clients.tf` mirrors the 8 live reservations exactly; see §14.5 for why it must stay exact |
| VPN (§10) | ✅ all three servers done 2026-09-13 — peers pending (§10) |
| Site settings (§11) | 🔧 Console page audited 2026-09-13; only the auto-speedtest decision is open |
| Imports | Deferred — next up now that the service account works |
| Static device IPs | ✅ live already has them; code mirrors live, so the plan is a no-op. *Changing* them in code is 🚫 blocked on #463 (§14.2) |

---

## 1. Networks / VLANs

### Live

| Name | Purpose | VLAN | Subnet | DHCP | mDNS |
|---|---|---|---|---|---|
| Vivacom Primary | wan (`WAN`) | – | – | – | – |
| Vivacom Secondary | wan (`WAN2`) | – | – | – | – |
| **Default (Untagged)** *(was UniFi Devices until 2026-09-13)* | corporate | untagged | 192.168.1.1/24 | .6–.254 | off |
| **UniFi Devices** *(new 2026-09-13, runbook Phase 0)* | corporate | **99** | 192.168.99.1/24 | .6–.254 | off |
| Main | corporate | 2 | 192.168.2.1/24 | .6–.254 | on |
| Guest | guest | 3 | 192.168.3.1/24 | .6–.254 | on |
| Public Servers | corporate | 4 | 192.168.4.1/24 | .6–.254 | on |
| Private Servers | corporate | 5 | 192.168.5.1/24 | .6–.254 | on |
| IoT | corporate | 6 | 192.168.6.1/24 | .6–.254 | on |
| **Qoax VPS** | corporate | 10 | **192.168.10.1/23** | **.10.11–.11.254** | on |
| FMI{Codes} VPS | corporate | 12 | 192.168.12.1/24 | .6–.254 | on |

### Differences vs. `tofu/unifi/core/networks.tf`

1. **`unifi_network.default` name.** Code says `"Default"`; live is `"UniFi Devices"`. Applying as-is renames the untagged LAN.
2. **VLAN 11 no longer exists.** Code declares `unifi_network.qoax_community_broadcast_vps` (VLAN 11, `192.168.11.1/24`). Live has no VLAN 11 — the Qoax network was widened to a **/23** that spans 192.168.10.0–192.168.11.255 instead. `core/outputs.tf` still exports `network_qoax_community_broadcast_vps_id`.
3. **Qoax network renamed and resized.** Code: `"Qoax Community VPS"`, `192.168.10.1/24`, DHCP `.6`–`.254`. Live: `"Qoax VPS"`, `192.168.10.1/23`, DHCP `192.168.10.11`–`192.168.11.254`.
4. ~~**mDNS is on everywhere.**~~ **Resolved 2026-09-13.** The site-wide Gateway mDNS Proxy was still at the factory `mode: "all"`; it is now `custom`, scoped to **Main + IoT** with 19 services (§11, `system/mdns.tf`). After that change the controller reports `mdns_enabled = true` on exactly Main and IoT and `false` on the other six — i.e. the per-network flag is *derived from* the site-wide scope (upstream #282). Code now matches: only `unifi_network.guest` changed (`true → false`), and the `TODO(mdns)` markers are gone.
5. Main / Guest / Public Servers / Private Servers / IoT / FMI{Codes} VPS otherwise match exactly (VLAN id, subnet, DHCP range, purpose).

> Checklist note: the checklist lists "Qoax VPS (10)" with no VLAN 11 — so the /23 consolidation was deliberate, and the code is the stale side.

---

## 2. Port profiles

### Live — five exist (updated 2026-09-13)

| Name | forward | native | PoE | 802.1X | tagged | pref | STP (`stp_port_mode`) | Port Mode (`stp_edge_state`) |
|---|---|---|---|---|---|---|---|---|
| **UniFi Device** | all | UniFi Devices (untagged) | auto | `force_authorized` | auto | auto | true | Infrastructure |
| **Host Device** | customize | Main (VLAN 2) | auto | `auto` | auto | manual | true | Edge |
| **Public Server** | customize | Public Servers (VLAN 4) | auto | `force_authorized` | auto | manual | true | Edge |
| **Private Server** | customize | Private Servers (VLAN 5) | auto | `force_authorized` | auto | manual | true | Edge |
| **IoT Device** | customize | IoT (VLAN 6) | auto | `force_authorized` | auto | manual | true | Edge |

The per-VLAN trio was recreated by hand on 2026-09-13.

**Full UI-field audit (2026-09-13).** Every field in the profile editor side panel was mapped to the `/rest/portconf` object and to the v0.55.0 `unifi_port_profile` schema (`tofu providers schema -json`):

| UI field | API key | Provider attribute | In code? |
|---|---|---|---|
| Name | `name` | `name` | ✅ |
| Port State (Active/Disabled) | `port_security_enabled` + empty allowlist (see §14.3) | `port_security_enabled`, `port_security_mac_address` | unset — live Active, matches |
| **Port Mode (Infrastructure/Edge)** | **`stp_edge_state`** | **none** | 🚫 UI-only. UniFi Device = Infrastructure, the other four = Edge |
| Native VLAN / Network | `native_networkconf_id` | `native_networkconf_id` | ✅ |
| Tagged VLAN Management | `tagged_vlan_mgmt` (`auto` = Allow All) | `tagged_vlan_mgmt` | ✅ |
| Auto PoE | `poe_mode` | `poe_mode` | ✅ |
| Auto Negotiate Link Speed | `autoneg` | `autoneg` | ✅ |
| Advanced (Auto/Manual) | `setting_preference` | `setting_preference` | ✅ (unset on UniFi Device = auto, matches) |
| QoS Mode | `qos_profile` | none | 🚫 UI-only; live `custom` with no policies (UI shows Off) |
| Precision Time Protocol | `precision_time_protocol_enabled` | none | 🚫 UI-only; live `true` |
| Storm Control | `stormctrl_*` | `stormctrl_*` | unset (computed) — live off, matches |
| Egress Rate Limit | `egress_rate_limit_kbps*` | same | unset (computed) — live off |
| Flow Control | `flow_control_enabled` | none | 🚫 UI-only; live `true` |
| Port Security / MAC filter | `port_security_*` | same | unset — live off |
| 802.1X Control | `dot1x_ctrl`, `dot1x_idle_timeout` | same | ✅ / unset (computed, live 300 s = provider default) |
| Port Isolation | `isolation` | `isolation` | unset (computed) — live false |
| Services → STP | **`stp_port_mode`** | `stp_port_mode` | ✅ `true` on all five |
| Services → STP Uplink / BPDU Guard | `stp_uplink` / `stp_bpdu_guard_enabled` | none | 🚫 UI-only; STP Uplink false everywhere; **BPDU Guard true on Host Device, Private Server, IoT Device since 2026-09-13**, false on UniFi Device (by design) and Public Server |
| Link Debounce | `link_debounce_auto`, `link_debounce` | none | 🚫 UI-only; Auto, 300 ms |
| Energy Efficient Ethernet | `eee_enabled` | none | 🚫 UI-only; false |
| LLDP-MED | `lldpmed_enabled` | `lldpmed_enabled` | unset (computed) — live true |
| Voice VLAN | `voice_networkconf_id` | `voice_networkconf_id` | unset — live none |
| Multicast Router Port | `multicast_router_mode` | `multicast_router_networkconf_ids` (different shape) | unset — live NONE |

**Correction to earlier analysis:** `stp_port_mode` is the Services → **STP** toggle, not "Port Mode: Edge". Edge mode is `stp_edge_state`, which the provider does not expose — so it is a UI-only property, and a from-scratch `tofu apply` would create these profiles as Infrastructure. The 2026-09-08 note that Host Device's `stp_port_mode = true` "is what the Port Mode: Edge toggle produces" was wrong; both were true, for different reasons.

### Code — `core/port_profiles.tf`

| Resource | Name | native | 802.1X | pref | `stp_port_mode` |
|---|---|---|---|---|---|
| `unifi_devices` | UniFi Device | default LAN | `force_authorized` | (auto) | true |
| `host_device` | Host Device | Main | `auto` | manual | true |
| `public_servers` | Public Server | Public Servers | `force_authorized` | manual | true |
| `private_servers` | Private Server | Private Servers | `force_authorized` | manual | true |
| `iot` | IoT Device | IoT | `force_authorized` | manual | true |

### Differences

**None as of 2026-09-13** for anything `unifi_port_profile` can express. The UI-only fields above (Port Mode Edge, Flow Control, PTP, …) are recorded as comments in `core/port_profiles.tf`. Resolved history:

1. ~~`unifi_devices` → live "UniFi Device" (singular), `dot1x_ctrl` `auto` vs `force_authorized`~~ — fixed in code 2026-09-08.
2. ~~`main` is really the live "Host Device"~~ — renamed, native → Main, `stp_port_mode` → true, 2026-09-08.
3. ~~`public_servers`, `private_servers`, `iot` do not exist live~~ — recreated by the user 2026-09-13 as **`Public Server`**, **`Private Server`**, **`IoT Device`** (singular names, `setting_preference = manual`, Port Mode Edge). Code aligned the same day; the resource addresses were kept (`public_servers`, `private_servers`, `iot`) so `devices/*.tf` and `core/outputs.tf` did not need to change.

Still true: **nothing on any switch references the per-VLAN profiles yet.** Aggregation port 1 and Pro Max port 19 use inline native-VLAN overrides (§3.3, §3.4). Moving ports onto the profiles is the `TODO(port-overrides)` work, blocked on §14.3.

---

## 3. Devices, names, IPs and port overrides

### 3.1 Device identity

| MAC | Live name | Live mgmt IP | Code name (`devices/*.tf`) | Diff |
|---|---|---|---|---|
| `28:70:4e:5c:b4:b2` | **UDM StKr** | WAN DHCP | UDM StKr | none (renamed in code before 2026-09-13) |
| `9c:05:d6:e2:6b:1d` | USW Pro Max 24 PoE | **static 192.168.99.2** (VLAN 99) | USW Pro Max 24 PoE | none since 2026-09-13 |
| `1c:6a:1b:98:38:ee` | USW Aggregation | **static 192.168.99.3** (VLAN 99) | USW Aggregation | none since 2026-09-13 |
| `9c:05:d6:d9:ad:79` | Living Room U7-Pro | **static 192.168.99.4** (VLAN 99) | Living Room U7-Pro | none since 2026-09-13 |
| `9c:05:d6:d9:af:65` | Bedroom U7-Pro | **static 192.168.99.5** (VLAN 99) | Bedroom U7-Pro | none since 2026-09-13 |

> **Management VLAN — 2026-09-13.** All four devices were re-homed from the untagged LAN to **UniFi Devices, VLAN 99** (runbook Phases 1–3) and code mirrors `mgmt_network_id` + the `.99.x` `config_network` on each. The old `.1.x` addresses in the tables above were replaced the same day.

> **`config_network` — corrected 2026-09-13.** All four devices declare the static addresses live reports, field for field (verified). Because the values match, the update `PUT` dropping the field is harmless: the read-back equals the plan and nothing is flagged. What §14.2 warns about is *changing* the address in code — that write never reaches the controller and fails post-apply. The 2026-09-08 `type = "dhcp"` block that *would* have failed is long gone.

Also:

- The controller itself is named **UDM StKr** (`super_identity.name`), hostname `UDM-StKr`. The checklist step is done; nothing in code manages it.
- **LED override:** both APs report `led_override = "on"` — i.e. LED forced **on**, not disabled. The checklist says "Disable LED on the Living Room and Bedroom APs". Either that step didn't take or it was reverted. Worth re-checking in the UI. The code has no `led_override` attribute at all either way. **This one is fixable today** — upstream #337 landed in v0.54.0, so `led_override = "off"` works on both APs (§14.8).
- `devices/u7_pro_living_room.tf` still carries `lifecycle { ignore_changes = [disabled] }` with a FIXME about the AP being offline/unadopted. It is adopted and online (`state = 1`) now, so that block can go.
- All three `lifecycle { ignore_changes = [port_override] }` blocks (UDM, USW Aggregation, USW Pro Max) are still in place for the provider port-disable crash. As long as they stay, **none of the port drift in §3.2–§3.4 will ever be reconciled by an apply** — the code is documentation only. **Keep them** until v0.56.0: upstream #430 (merged, unreleased) shows a single declared `port_override` silently strips settings from *every* port on the device, which is very likely what flattened these switches in the first place (§14.3).

### 3.2 UDM StKr — ✅ aligned 2026-09-13

| Port | Live (= code) | Note |
|---|---|---|
| 1, 9 | *no override* | WAN2 / WAN1. Binding a WAN to a physical port is UniFi OS Internet configuration, not a `port_override` — the pre-reset code's `native_networkconf_id = var.wan_*` blocks never corresponded to anything stored. Removed, along with the `wan_primary_id`/`wan_secondary_id` plumbing into the `devices` module. `FIXME(unifi-ui-only)` in the file. |
| 2–8 | `Port N`, **disabled** | Port 2 disabled through the UI to learn the gateway's shape, 3–8 written as identical copies. The gateway stores a **smaller** disabled object than the switches: `forward "disabled"`, `port_security_enabled true` + `[]`, `tagged_vlan_mgmt "block_all"`, no native/voice network, `setting_preference "auto"`, `autoneg true`, `isolation/egress_rate_limit/port_keepalive false`, `sd_wan_underlay_port false` — no dot1x, STP or PoE keys at all. |
| 10 | `SFP+ 1`, UniFi Device profile | Uplink to the Pro Max. The pre-reset code had the **Private Servers** profile here — wrong for an inter-switch trunk. |
| 11 | `USW-Aggregation`, UniFi Device profile | Renamed from `SFP+ 2`. |

Written via one `PUT /rest/device/<id>` (9 entries); read back, ports 10/11 unchanged except the rename, all four uplink/WAN ports still `up`, all four downstream devices still `state 1`.

#### Port assignments vs. the UI — what is *not* in tofu (2026-09-13 audit)

Profile assignments now match live on every port of every device. What the UI stores beyond that, per override shape:

| Shape | Provider-expressible — now declared explicitly | UI-only — `FIXME(unifi-ui-only)` in the file |
|---|---|---|
| Profiled port (all devices) | `name`, `poe_mode` (where present), `setting_preference`, `port_profile_id` — that *is* the whole stored object | none at this layer (the profile layer has its own FIXMEs in `core/port_profiles.tf`) |
| Disabled port, switches (Pro Max 9–11, Agg 2–7) | `forward`, `port_security_enabled`, `port_security_mac_address`, `tagged_vlan_mgmt`, `native_networkconf_id = null`, `voice_networkconf_id = null`, `setting_preference`, `poe_mode`, `autoneg`, `dot1x_ctrl`, `lldpmed_enabled`, `stp_port_mode`, `isolation`, `egress_rate_limit_kbps_enabled`, `port_keepalive_enabled` | `stp_edge_state "enabled"`, `stp_bpdu_guard_enabled true`, `stp_uplink false`, `eee_enabled false`, `link_debounce_auto true`, `multicast_router_mode "NONE"`, `sd_wan_underlay_port false`; `dot1x_idle_timeout 300` is expressible but left at the provider default |
| Disabled port, gateway (UDM 2–8) | same minus dot1x/STP/PoE (the gateway doesn't store them) | `sd_wan_underlay_port false` |
| No override (Pro Max 25, UDM 1, 9) | nothing to declare | Pro Max 25 runs on switch defaults; UDM 1/9 are WAN-bound in UniFi OS |
| Agg port 1 specifically | profile assignment | BPDU Guard now comes from the Private Server profile (on) — UI-only |

`FIXME(unifi-ui-only)` count: Pro Max 9, Aggregation 9, UDM 2, `port_profiles.tf` 9.

### 3.3 USW Aggregation — ✅ aligned 2026-09-13

| Port | Live (= code) | Note |
|---|---|---|
| 1 | `Servacho-Gosho`, **Private Server profile**, pref auto | Was an inline native-VLAN override with ~20 explicit fields. Moved to the profile at the user's request. The inline override had BPDU Guard on and the profile initially did not; **BPDU Guard was enabled on the Private Server profile later the same day** (UI-only field, set via the API), so nothing was lost. Everything else was identical to the profile: native Private Servers, `force_authorized`, Port Mode Edge, tagged Allow All, STP on, LLDP-MED on, no isolation/storm control/rate limit. Servacho-Gosho verified still up at `192.168.5.10` afterwards. |
| 2–7 | `SFP+ N`, **disabled** | Same stored shape as Pro Max 9 (below). Previously no override at all (the code's `forward = "disabled"` blocks were phantoms). |
| 8 | `UDM-Pro-Max`, UniFi Device profile, pref auto | Renamed from `SFP+ 8`. |

Written via `PUT /rest/device/<id>` with the full `port_overrides` array (8 entries); read back and verified.

### 3.4 USW Pro Max 24 PoE — ✅ aligned 2026-09-13

Live, grouped (25 overrides; port 25 has none):

| Ports | Live (= code) | Names |
|---|---|---|
| 1–5 | Host Device, poe auto, pref auto | `LR-01`…`LR-05` |
| 7, 8 | Host Device | `Balc-01`, `Balc-02` |
| 13, 14 | Host Device | `K-01`, `K-02` |
| 15, 16, 17, 19, 21, 22 | Host Device | `BR-07`, `BR-08`, `BR-01`, `BR-03`, `BR-05`, `BR-06` |
| **20** | **Host Device** | `BR-04` — the pre-reset code had the Public Servers profile here; live was Host Device and stays so by the user's decision (2026-09-13). Nothing plugged in. |
| 6 | IoT Device, pref manual | `Port 6` — Living Room TV |
| 12, 18 | Private Server, pref manual | `Port 12`, `Port 18` — the two JetKVMs |
| **9, 10, 11** | **disabled** | `Port 9`…`Port 11` |
| 23, 24 | UniFi Device, pref auto | `LR-WiFi`, `BR-WiFi` (AP uplinks) |
| 26 | UniFi Device, pref auto | `UDM-Pro-Max` (SFP+ 2) |
| 25 | *no override* | `SFP+ 1` — the live uplink to the UDM |

**What "disabled" actually is on the wire.** Port 9 was disabled through the UI (Port Profile toggle off → Port State: Disabled → Apply) and read back; ports 10, 11 and Aggregation 2–7 were then written as byte-identical copies. The stored override is a full manual one: `forward "disabled"`, `port_security_enabled true` + `port_security_mac_address []`, `tagged_vlan_mgmt "block_all"`, no `native_networkconf_id`, `setting_preference "manual"`, plus carried-over defaults (`dot1x_ctrl auto`, `stp_port_mode true`, `stp_edge_state enabled`, `stp_bpdu_guard_enabled true`, `lldpmed_enabled true`, `autoneg true`, `poe_mode auto`, `link_debounce_auto true`, `eee_enabled false`, `multicast_router_mode NONE`, `sd_wan_underlay_port false`, `isolation false`, `egress_rate_limit_kbps_enabled false`, `port_keepalive_enabled false`, `stp_uplink false`, `dot1x_idle_timeout 300`). The port table confirms `forward = disabled` on all three. This settles §14.3's point empirically: `forward = "disabled"` alone was never it.

Stored shape for profiled ports is `{name, poe_mode?, setting_preference, portconf_id}` — no `forward`, no `op_mode`. The code blocks now use exactly that. Ports 23/24/26 have no `poe_mode` key.

Live write: two `PUT /rest/device/<id>` calls with the full array; all overrides not being changed were diffed before/after and matched except for the intended renames.

> **Ports 6 and 18 — resolved 2026-09-13**, see the change log; port 12 likewise. The `Checklist vs. live discrepancy` note from 2026-09-08 (Host Device on 6/18, port 19 hand-rolled) is moot: 6 and 18 are on their profiles, and 19 is on Host Device like its neighbours.

---

## 4. WANs (`core/wans.tf`)

| Attribute | Live | Code |
|---|---|---|
| Primary: type / v6 / priority / lb type | dhcp / disabled / 1 / weighted | same ✅ |
| Primary: provider capabilities | 600000 / 400000 | same ✅ |
| **Primary: load balance weight** | **99** | **50** |
| Secondary: type / v6 / priority / lb type | dhcp / disabled / 2 / failover-only | same ✅ |
| **Secondary: provider capabilities** | **not set** | **150000 / 40000** |
| **Secondary: load balance weight** | not set | 50 |

Physical port assignment (WAN1 → UDM port 9, WAN2 → UDM port 1) is a UniFi OS concern and is not represented in the live Network config — see §3.2.

---

## 5. Wireless (`wireless/wlans.tf`)

All four SSIDs exist live with the right networks, bands, AP group and security type.

| SSID | Match | Diffs |
|---|---|---|
| `StKr` | ✅ | none — `wpaeap`, Main, RADIUS profile, WPA3 + transition, PMF optional |
| `StKr_Guest` | ✅ | none — `wpapsk`, Guest, `is_guest = true` |
| `StKr_IoT` | ⚠️ | code sets **`hide_ssid = true`**; live is **false** |
| `StKr_IoT_2.4GHz` | ⚠️ | code sets `wpa3_support = false`, `wpa3_transition = false`, `pmf_mode = "disabled"`; live is **true / true / optional** |

The `StKr_IoT_2.4GHz` diff matters: applying the code would drop WPA3 from that SSID. If it was created by cloning `StKr_IoT` in the UI, live is just the clone's inherited settings — decide which you actually want for the 2.4 GHz-only IoT gear.

**Keep the `ignore_changes = [passphrase, wlan_bands, wlan_band]` blocks.** All four SSIDs declare `"6g"`, and the fix for `6g` being dropped from the create response (#406) is merged but unreleased — see §14.4, which also notes that a third of that FIXME's rationale is now stale.

---

## 6. RADIUS and 802.1X

### Live

- Site RADIUS setting: `enabled = true`, `configure_whole_network = true` (wired **and** wireless), shared secret set, auth 1812 / acct 1813, tunnelled reply on.
- `global_switch.dot1x_portctrl_enabled = true`; `dot1x_fallback_networkconf_id` is **empty**.
- RADIUS users: **`a.penchev`, `e.pencheva`, `vl.penchev`, `v.todorova`** — all four `tunnel_type 13`, `tunnel_medium_type 6`, `vlan 2`, `group_policy GLOBAL`. *(Updated 2026-09-13 — the last two were created by hand; at the original 2026-09-08 read only the first two existed.)*
- Default RADIUS profile with `vlan_enabled = true`, `use_usg_auth_server = true`.

### Differences

1. **The site RADIUS setting is unmanaged.** `tofu/unifi/variables.tf` declares `radius_profile_secret` (and `tofu/unifi_module.tf` feeds it from Vault at `secret/unifi/radius/profile`), but **nothing consumes it** — there is no `unifi_setting_radius` resource anywhere. Dead variable, and the shared secret you set by hand is not in code.
2. **Global 802.1X port control is unmanaged.** It exists only inside the commented-out `unifi_setting_switch` block in `system/settings.tf`. That block also proposes `fallback_vlan_id = var.network_guest_id`; live has **no** fallback network configured. If you uncomment it later, that's a behaviour change, not a no-op.
3. **RADIUS users: ✅ in sync as of 2026-09-13.** Code declares four (`a.penchev`, `e.pencheva`, `vl.penchev`, `v.todorova`) and live now has the same four, each with exactly the attributes `unifi_radius_user` manages (`tunnel_type 13`, `tunnel_medium_type 6`, `vlan 2`). The one live-only field, `group_policy = "GLOBAL"`, is identical on the old and new pairs and is not exposed by the provider, so it is not drift. The Vault `radius_users` map carries all four keys (confirmed by the user 2026-09-13). One thing still stands between this and a clean apply:
   - `unifi_radius_user` has no `allow_existing`, so the four live accounts need a `tofu import` first (state still holds the pre-reset `_id`s) — otherwise the create `POST` is rejected for a duplicate name. This applies to every resource on the rebuilt controller, not just these.

---

## 7. Firewall (`security/firewall.tf`)

### Live zones

| Zone | Networks |
|---|---|
| Internal | Default (Untagged), UniFi Devices (VLAN 99), Main, Private Servers, Qoax VPS, FMI{Codes} VPS |
| IoT *(non-default zone, verified 2026-09-13)* | IoT |
| External | Vivacom Primary, Vivacom Secondary |
| Gateway | – |
| Vpn | – |
| **Hotspot** | **Guest** |
| **Dmz** | **Public Servers** |

Both checklist assignments (Hotspot ← Guest, DMZ ← Public Servers) are done, and the new firewall UI is active.

### Differences

1. **`Hotspot` ← `Guest` is not in code.** Only the DMZ zone is managed.
2. **Zone name casing.** Code uses `name = "DMZ"`; the controller reports `"Dmz"`. Likely harmless, but if the provider matches by exact name it will try to rename or fail to find it.
3. **Zero custom firewall policies exist live.** All 88 policies are predefined. `unifi_firewall_policy.allow_main_to_iot` in code has never been applied — an apply will create it. Decide whether you still want Main → IoT open. Note policy **ordering cannot be managed at all** through the provider (§14.9) — it will land wherever the controller appends it.
4. **Adding the Hotspot zone is load-bearing, not cosmetic.** On zone-based-firewall controllers a network only keeps `purpose = "guest"` while it belongs to the Hotspot zone; elsewhere the controller rewrites it to `corporate`. `unifi_network.guest` declares `purpose = "guest"` while nothing in code owns that zone (§14.9).

---

## 8. Port forwards (`security/port_forwards.tf`)

### Live — one rule

| Name | Proto | WAN | Forward |
|---|---|---|---|
| **NGINX Server** | tcp_udp | wan 80,443 | **192.168.5.58**:80,443 |

### Differences — ✅ resolved 2026-09-13

Re-read the same day: still exactly one live rule, unchanged. The user chose to keep what is live. `security/port_forwards.tf` now declares only `nginx_proxy`, renamed **`NGINX Server`** and pointed at **`192.168.5.58`** (resource address unchanged). Dropped from code: `fmicodes_db` (5432), `fmicodes_ssh` (2242), `fmicodes_ssh_worker` (2243) — the `.5.200/.201` nodes are still live clients, so this is a deliberate end to their public SSH/Postgres exposure — and the two `count = 0` placeholders `minecraft_server` and `fmicodes_intercom`. Live-only fields (`enabled`, `log`, `src_limiting_enabled`, `destination_ips`) are all defaults and have no provider attribute.

---

## 9. Fixed-IP clients (`system/clients.tf`)

### Live — four fixed IPs *(2026-09-08; seven as of 2026-09-13 — added `192.168.5.23` jetkvm-ce4ac3437e0d935d, `192.168.6.10` Living Room TV, `192.168.6.11` Bedroom TV)*

| Name | MAC | IP |
|---|---|---|
| `fmicodes-master-node` | `bc:24:11:c3:e5:f4` | 192.168.5.200 |
| `fmicodes-worker-node-1` | `bc:24:11:23:76:b5` | 192.168.5.201 |
| `hackjamhub-intercom` | `bc:24:11:8a:b7:98` | 192.168.5.215 |
| *(unnamed)* | `38:05:25:30:79:97` | 192.168.5.10 — this is Servacho-Gosho, last seen on USW Aggregation port 1, Private Servers |

> **Rewritten 2026-09-13.** `system/clients.tf` now declares exactly the eight live reservations (`.5.10`, `.5.20`, `.5.23`, `.5.200`, `.5.201`, `.5.215`, `.6.10`, `.6.11`) with only the attributes the controller has — `name` on the two TVs, `network_id` on the port-12 JetKVM, nothing else. Because every in-place `unifi_client` update fails at v0.55.0 (#428, §14.5), the file must stay attribute-exact: name or bind a client in the UI first, then mirror. Six of the eight are unnamed on the controller.

### Differences

1. **All ten `unifi_client` resources in code are stale.** None of `MICHELANGELO`, `jetkvm`, `SAMI-DEV-MACHINE`, `rpi-petacho`, `networkboot-server`, `tsb-mint`, `DJAM-11`, `nixos`, `minecraft-fabric-server` or `Servacho-Gosho-JetKVM` exist on the rebuilt controller. This is the single biggest block of dead config.
2. **None of the four live fixed IPs are in code**, including `hackjamhub-intercom` (which isn't on the checklist either — undocumented manual step).
3. **MAC mismatch for Servacho-Gosho.** The checklist says "Set Servacho-Gosho IP to 192.168.5.10", and live has `38:05:25:30:79:97` → `.10`. Code's closest entries are `servacho_gosho_jetkvm` (`38:52:53:0a:09:87` → 192.168.5.20) and `jetkvm` (`30:52:53:08:45:16` → 192.168.5.21) — different MACs, different IPs. Note `192.168.5.10` is also the Proxmox endpoint hardcoded in `tofu/providers.tf`.
4. The live client is **unnamed** — you set the fixed IP but never gave it a name.
5. Live fixed IPs are plain `fixed_ip` on the client object with **no `network_id` binding**; code sets `network_id` on every client.

---

## 10. VPN (`system/vpn.tf`)

**Decided and (mostly) done 2026-09-13.** Three remote-access servers, one tunnel subnet each, third octet = order:

| # | Live | Code |
|---|---|---|
| 1 | **Teleport** (WiFiman) enabled, `192.168.7.1/24` — the admin's current way in | 🚫 `FIXME(unifi)` comment block only: Teleport is a *site setting* (`teleport`), not a network, and `unifi_setting` v0.55.0 has no such block. No name either, so "StKr … Server" cannot apply |
| 2 | **StKr OpenVPN Server** — created in the UI 2026-09-13: `192.168.8.1/24`, UDP `1194`, local RADIUS (Default profile, the four accounts), auto DNS, controller-generated certs | ✅ `unifi_vpn_server.openvpn`, attribute-exact; `FIXME(unifi-ui-only)` for protocol, MSS clamp, MTU, compression, DHCP range |
| 3 | **StKr WireGuard Server** — created from the shell 2026-09-13 with the OpenBao key: `192.168.9.1/24`, UDP `51820`, WAN `any`, `setting_preference manual`, no peers yet | ✅ `unifi_vpn_server.wireguard`, attribute-exact; `private_key` from OpenBao `secret/unifi/vpn/wireguard` (public key `mmWQkf3m…EKSw=` matches live) |

Findings on the way:

- The controller rejects any explicit OpenVPN cipher other than `AES_256_CBC` / `BF_CBC` (`api.err.InvalidValue`) and the UI sends none. The old commented block asked for `AES_256_GCM` — the probable real cause of its "constant 400 Invalid Payload" FIXME, which blamed the provider. That block and its FIXME are gone; `encryption_cipher` stays unset.
- The bare `POST /rest/networkconf` for an OpenVPN server also failed with `api.err.MissingLocalPort` for every port field name tried; the UI's payload uses `local_port`. Created via the UI instead, read back, mirrored.
- ~~The OpenBao `secret/unifi` controller credentials were rejected~~ — the tofu service account had not survived the factory reset. **Recreated by hand 2026-09-13** (Admins → Create New, local admin, same username/password as the secret); login verified from the shell: `site_role admin`, `is_super true`. `tofu plan` is unblocked on the credential side.
- WireGuard was then created from the shell: `POST /rest/networkconf` with `vpn_type wireguard-server`, `local_port` (the generic port field — `openvpn_local_port`/`openvpn_port` were the wrong guesses earlier), `wireguard_interface`, `wireguard_local_wan_ip`, `x_wireguard_private_key` piped from OpenBao and `wireguard_public_key` derived with `wg pubkey`. Accepted first try; read-back public key equals the derived one.
- Site Magic (`magic_site_to_site_vpn`) is enabled by default with generated keys and no tunnels — UI-only, documented in the same FIXME.
- Firewall: both new networks join the `Vpn` zone automatically (Vpn → Internal/External/Gateway/Hotspot/Dmz allow, **Vpn → IoT block**). **Decided 2026-09-13: no Vpn → IoT policy.**
- Peers: `unifi_wireguard_peer` (v0.55.0) covers WireGuard clients. **Decided 2026-09-13: none for now**; devices will be added later, one resource each.

---|---|
| **Teleport** enabled, `192.168.7.1/24` — the only VPN server; it is how the admin session reaches the controller today | nothing — `unifi_setting` at v0.55.0 has no `teleport` block, so this is **UI-only** |
| **Site Magic** (`magic_site_to_site_vpn`) enabled, keys present — the controller default, no tunnels | nothing — no provider resource |
| **No WireGuard server**, no OpenVPN, no L2TP; `/rest/wireguardpeer` returns `InvalidObject` (no server to hold peers) | `unifi_vpn_server.wireguard` — `.StKr WireGuard Server`, `192.168.8.1/24`, UDP 51820, `private_key` from Vault `secret/unifi/vpn/wireguard` |
| `Vpn` zone: default policies only (Vpn → Internal/External/Gateway/Hotspot/Dmz allow, **Vpn → IoT block**, External → Vpn block) | `security/firewall.tf` declares nothing for the zone |
| `radius` setting enabled, `configure_whole_network`, `tunneled_reply`; one RADIUS profile (`use_usg_auth_server`) | OpenVPN block (commented) wants `data.unifi_radius_profile.default`, undeclared in `system` |

Observations:

- The WireGuard block is **code ahead of reality**, not drift: nothing was ever applied. The leading dot in `.StKr WireGuard Server` looks accidental. `192.168.8.1/24` collides with nothing (Teleport `.7`, management `.99`).
- The provider (v0.55.0) covers what is needed once a server exists: `unifi_vpn_server` (WireGuard/OpenVPN/L2TP, `dns`, `wan`) and **`unifi_wireguard_peer`** (`name`, `interface_ip`, `public_key`, `allowed_ips`) — peers can be code, their public keys are not secret.
- The controller refuses to create a WireGuard server without a private key (`api.err.WireguardMissingPrivateKey`; the provider generates one if unset). For code-follows-live, generate the key pair **outside** the controller (`wg genkey | tee private | wg pubkey`), put the private key in Vault first, paste it into the UI's Private Key field on creation — then `var.wireguard_private_key` and the controller agree and a later `tofu import` is clean.
- The OpenVPN block: FIXME unverified upstream (§14.6), references an undeclared data source, and Teleport + WireGuard already cover the remote-access need. Candidate for deletion.
- Firewall: a WireGuard network lands in the `Vpn` zone automatically, inheriting the defaults above. Vpn → IoT is blocked; Home Assistant is on Private Servers so that is not a problem, but reaching IoT devices directly over VPN would need a policy (`security/firewall.tf`).

Decisions needed: keep Teleport (yes, recommended — zero-config for phones, and it is the current lifeline); WireGuard server name / subnet / port; which peers; drop OpenVPN. Then: create live in the UI → read back → align `system/vpn.tf` → add `unifi_wireguard_peer` blocks.

---

## 11. Site settings (`system/settings.tf` and friends)

| Setting | Live | Code | Diff |
|---|---|---|---|
| Country | `100` (Bulgaria) | `100` | ✅ |
| NTP | `setting_preference = auto` | same | ✅ |
| IGMP snooping | `enabled = false` | `enabled = false` | ✅ |
| **Auto speedtest** | **setting key absent entirely** | `enabled = true`, `cron_expr = "0 4 * * *"` | code would create it — decision pending, flagged in a FIXME |
| Updates schedule | `mgmt.auto_upgrade = true`, `auto_upgrade_hour = 3`, no weekday | ✅ `mgmt` block added 2026-09-13 (`auto_upgrade`, `auto_upgrade_hour`, `advanced_feature_enabled`, `debug_tools_enabled`, `unifi_idp_enabled`, `wifiman_enabled`) | weekday stays UniFi OS-only |
| **Console page** (Control Plane → Console, audited 2026-09-13) | Name `UDM StKr`; TZ Europe/Sofia; Screen on 80 %, idle 300 s, sync, touch; Night Mode 22:00–08:00; Email = UI Mail Server; Analytics Off; Support File Full; no certificates; Remote Access on; Direct Remote Connection off; SSH off | ✅ `lcm` block added (enabled, brightness, idle_timeout, sync, touch_event); country already managed | everything else 🚫 `FIXME(unifi)` in `system/settings.tf`: timezone, night mode, mail, analytics, support file, certificates, remote access, SSH, backup schedule are UniFi OS or `super_*` settings without a provider block |
| **Admin accounts** | Owner + local admin `servacho-managment-plane` (is_super, site admin) | 🚫 no provider resource — documented as `FIXME(unifi)` in new `system/admins.tf` | UI-only |
| Captive portal | `guest_access.portal_enabled = false` | not managed | **unmanaged** (checklist step done by hand) |
| mDNS | **`mode = "custom"`, `enabled_for = "some"`, Main + IoT, 19 services** (set 2026-09-13) | commented-out `unifi_setting_mdns` in `system/mdns.tf`, now with the verified identifier catalogue and wire format | 🚫 unmanaged (no provider resource) — **manual runbook item, live matches the documented intent** |
| Global switch | rstp, jumbo off, flowctrl off, DHCP snooping on, auto STP edge detection off, 802.1X on, RADIUS profile bound | commented-out `unifi_setting_switch` | **unmanaged** |
| Etherlighting | controller defaults (per-network auto colours; speed defaults `10M=#FFC105` etc.) | commented-out `unifi_setting_ether_lighting` with custom FE/GbE/2.5GbE/10GbE colours + a device-level block | **unmanaged**, and the live speed colours are *not* the ones in code |
| WAN SLA | not checked | commented-out `unifi_wan_sla` | **unmanaged** |

Notes:

- **Updates schedule.** The checklist says "Weekly at 4AM on Sunday". The Network app only reports `auto_upgrade_hour = 3` with no weekday, which means the weekly/Sunday/4 AM schedule is stored at the **UniFi OS** level, outside the Network application the provider talks to. Not expressible in this provider — document it as a manual step.
- **InnerSpace** is a UniFi OS application install. Same story: out of reach of `ubiquiti-community/unifi`, document as manual.
- `usw_pro_max_24_poe.tf` sets `flowctrl_enabled = false` and `jumboframe_enabled = false` per-device; those are now site-global under `global_switch` and already match. Harmless but redundant.

---

## 12. Dead / broken plumbing in the code

Independent of live state, worth cleaning while you're in here:

1. **`radius_profile_secret`** — declared in `tofu/unifi/variables.tf`, passed in from Vault by `tofu/unifi_module.tf`, **never referenced**. Either add the `unifi_setting_radius` resource it was meant for, or delete both ends.
2. **`network_default_id`** — passed into the `devices` module by `main.tf` and declared in `devices/variables.tf`, **never used** by any device file.
3. **`network_qoax_community_broadcast_vps_id`** output — points at a network that no longer exists on the box.
4. ~~**`port_profile_public_servers_id` / `port_profile_iot_id`** — each used exactly once~~ — the profiles exist again (2026-09-13), so the plumbing is live, not dead. Whether ports 20 and 6 end up on them is the §3.4 port-override decision.
5. **Three `ignore_changes = [port_override]` blocks** — until upstream PR #470 *and* the unreleased #430/#438 land, every port assignment in `devices/*.tf` is decorative. Anything you "fix" there today has no effect on the controller (§14.3).
   - The FIXME text itself is worth updating: it blames "a bug parsing the empty MAC allowlist required for the new UniFi OS Port State toggles", which is #470 and correct — but omits that `forward = "disabled"` was never the right mechanism, and that #430 (whole-array replacement stripping undeclared ports) is the more dangerous of the two.
6. **`system/vpn.tf`** OpenVPN block references `data.unifi_radius_profile.default`, which the `system` module never declares.
7. Untracked working-tree changes: trailing-newline cleanup in `core/port_profiles.tf`, and the WireGuard rename + subnet move in `system/vpn.tf`.

---

## 13. Live-only, undocumented manual steps

Things the controller has that are on neither the checklist nor in code:

- ~~**USW Aggregation port 1** — manual override~~ — moved to the Private Server profile 2026-09-13 (BPDU guard dropped in the process, see §3.3).
- ~~**USW Pro Max port 19** — manual override~~ — on Host Device since before 2026-09-13.
- ~~**USW Pro Max ports 6 and 18** — on Host Device~~ — resolved 2026-09-13, both on their per-VLAN profiles.
- **`hackjamhub-intercom`** fixed IP `192.168.5.215`.
- The **Qoax /23** widening (implied by the checklist's single "Qoax VPS (10)" entry, but the /23 itself isn't written down).

---

## 14. Provider bug surface — `ubiquiti-community/unifi`

Checked against upstream on **2026-09-08**. This section is the binding constraint on everything above: several "differences" in §1–§13 **cannot be fixed in code** at the pinned version, and a couple of things already in the code are guaranteed apply failures today.

### 14.1 Version situation

- We pin `~> 0.55.0` in five `versions.tf` files. **v0.55.0 (2026-07-10) is still the latest release.**
- `main` is ~88 commits ahead with **13 unreleased CHANGELOG entries**, several of which are exactly our pain points. Upstream issue [#475](https://github.com/ubiquiti-community/terraform-provider-unifi/issues/475) is an open request for a v0.56.0 cut; no maintainer response yet.
- Net effect: **every August 2026 fix is merged but unavailable to us.** Options are wait for v0.56.0, or pin a `main` commit via a local provider build. Waiting is the sane default; just don't plan work that silently assumes those fixes.

### 14.2 The root cause behind most of our FIXMEs

`buildMinimalUpdateDevice` in `unifi/device_resource.go` (verified at tag `v0.55.0`) assembles the update `PUT` from a hand-picked subset of fields:

```go
minimalDevice := &unifi.Device{
    ID, Type, MAC, Name, PortOverrides, MgmtNetworkID,
    LedOverride, LedOverrideColor, LedOverrideColorBrightness,
    SwitchVLANEnabled, MeshStaVapEnabled, RadioTable,
}
```

`modelToAPIDevice` populates far more than that (`ConfigNetwork`, `FlowctrlEnabled`, `JumboframeEnabled`, `Disabled`, `StpVersion`, `StpPriority`, …) and `deviceToModel` reads all of them back — but on **update** they never reach the controller. The write is dropped, the post-apply read returns the old value, and you get `Provider produced inconsistent result after apply`. They *do* work on create/adopt, which is why this class of bug is so confusing.

Fields we care about that are **silently dropped on update at v0.55.0**:

| Field | Consequence for us |
|---|---|
| `config_network` | **Cannot set the static mgmt IPs** on the switches/APs (§3.1) |
| `flowctrl_enabled`, `jumboframe_enabled` | Declared on `usw_pro_max_24_poe`, never sent |
| `disabled` | Related to the `ignore_changes = [disabled]` FIXME on the Living Room AP |
| `stp_version`, `stp_priority` | Open issue [#476](https://github.com/ubiquiti-community/terraform-provider-unifi/issues/476), still missing on `main` |

> **Corrected twice.** 2026-09-08: adding `config_network` with values that *differ* from live fails post-apply, and the then-present `type = "dhcp"` block against a live static `.2` was a guaranteed failure. 2026-09-13: with the code now declaring exactly what live reports, the dropped field is harmless — the read-back matches the plan. The constraint is only that `config_network` is effectively read-only from code until PR [#463](https://github.com/ubiquiti-community/terraform-provider-unifi/pull/463) ships (it adds `config_network`, `lcm_brightness` and `outlet_enabled` to the builder — but *not* the STP fields).

### 14.3 Our three `ignore_changes = [port_override]` blocks

The FIXME cites PR **#470**, and it's accurate but incomplete.

**[#470](https://github.com/ubiquiti-community/terraform-provider-unifi/pull/470) — still OPEN** (`fix(port_profile): keep an explicitly empty port_security_mac_address`, last touched 2026-08-31). `portProfileToModel` collapses an empty MAC allowlist to `SetNull`, so `port_security_mac_address = []` can't be held in state and every apply errors.

**The important part is buried in that PR's description, and it invalidates a design assumption in our code:**

> the Port State radio is `port_security_enabled` with an empty allowlist. `forward = "disabled"` alone does not disable a port. A profile carrying `forward` disabled, `block_all` and no native network still renders as Active until port security is on.

We have **17 `port_override` blocks** using `forward = "disabled"` + `poe_mode = "off"` to "disable" ports (UDM 2–8, USW Aggregation 2–7, Pro Max 9–11). **Those were never disabling anything** — they'd render as Active. That also explains the branch history (`fix(unifi): actually disable ports using Disabled port profile` → … → `fix(unifi): ignore port overrides to allow manual port state`): the approach couldn't have worked, and the git log is a record of discovering that the hard way. It matches live, too — none of those ports carry an override on the controller.

**Additional port_override fixes merged on `main` but unreleased** (all listed in #475):

| PR | What it fixes |
|---|---|
| [#430](https://github.com/ubiquiti-community/terraform-provider-unifi/pull/430) (with #266, #213) | **A single declared `port_override` strips settings from *every* port on the device.** `UpdateDevice` compares `port_overrides` as one JSON blob, so one field difference full-replaces the array from a round-trip through `DevicePortOverrides`, dropping fields it doesn't model (`stp_edge_state`, `stp_bpdu_guard_enabled`, `multicast_router_mode`, `sd_wan_underlay_port`) and everything at a zero value. Undeclared ports get wiped too, the plan shows nothing, and the apply reports success. |
| [#438](https://github.com/ubiquiti-community/terraform-provider-unifi/pull/438) | Zero declared `port_override` blocks + any other change (e.g. a rename) must resend the controller's current overrides, not `null` (400) and not `[]` (wipes everything). |
| [#427](https://github.com/ubiquiti-community/terraform-provider-unifi/pull/427) | Empty `port_overrides` sent as `[]` where the device has `null`, manufacturing a spurious change some controllers reject. |

**#430 is almost certainly what ate the port configuration.** Live has *zero* custom port names across all three devices (§3.2–§3.4) — precisely the signature of "declared one port, silently stripped the rest". Keep all three `ignore_changes = [port_override]` blocks in place until v0.56.0 ships #430 + #438; removing them early risks flattening the switch again.

### 14.4 `wireless/wlans.tf` — the `ignore_changes = [passphrase, wlan_bands, wlan_band]` FIXMEs

Three separate upstream problems sit behind that one workaround, and they have different statuses:

| Attribute | Status |
|---|---|
| `wlan_bands` with `"6g"` | [#406](https://github.com/ubiquiti-community/terraform-provider-unifi/pull/406) — **merged on `main`, unreleased.** Some controllers silently drop `6g` from the *create* response while accepting the same payload on update; the fix re-asserts with a follow-up update. All four of our SSIDs declare `["2g","5g","6g"]`, so at v0.55.0 a from-scratch create can still fail. **Keep this ignore.** |
| `passphrase` | [#464](https://github.com/ubiquiti-community/terraform-provider-unifi/issues/464) — **OPEN**, filed 2026-08-27 against 0.55.0: `.passphrase: inconsistent values for sensitive attribute` on open/guest WLANs. Doesn't hit us directly (all four SSIDs are `wpaeap`/`wpapsk`), but it's the same null-vs-empty confusion. `passphrase_wo` (write-only, #398) is merged-unreleased. **Keep this ignore.** |
| WLAN defaults | [#323](https://github.com/ubiquiti-community/terraform-provider-unifi/issues/323) — **fixed in v0.53.0.** `radius_profile_id`, `bc_filter_list` and the minimum-data-rate fields became `Optional + Computed`. The FIXME's "provider returns different structures" wording predates this; that half is stale. |

So the ignore blocks are still justified, but the comment should say *why* — it currently blames a vague structural mismatch rather than the specific `6g`-on-create asymmetry.

### 14.5 `system/clients.tf` — a fix we're missing

[#428](https://github.com/ubiquiti-community/terraform-provider-unifi/issues/428) — **merged as #447 on `main`, unreleased.** `last_ip` and `hostname` used `UseStateForUnknown`, which pins the planned value to prior state; the controller legitimately reports a different value between plan and apply (lease renewal, re-association), so **every in-place `unifi_client` update fails** with `Provider produced inconsistent result after apply: .last_ip`.

Resolution chosen 2026-09-13: **mirror live exactly** rather than delete. Creates work and a no-diff plan is a no-op, so an attribute-exact `clients.tf` is safe; only a *diff* triggers the failing update path. Also unreleased: clearing `fixed_ip` ([#400](https://github.com/ubiquiti-community/terraform-provider-unifi/pull/400)).

### 14.6 `system/vpn.tf` — the OpenVPN `CustomizeDiff` FIXME

I could not find an upstream issue or PR matching this. The two closed `unifi_vpn_server` issues ([#255](https://github.com/ubiquiti-community/terraform-provider-unifi/issues/255) private-key-required-on-create, [#256](https://github.com/ubiquiti-community/terraform-provider-unifi/issues/256) private key leaked in cleartext error messages) are both about WireGuard.

Two things follow: the OpenVPN behaviour is **unreported upstream**, and the FIXME's `CustomizeDiff` wording is suspect — that's SDKv2 vocabulary, and this provider is plugin-framework (`ModifyPlan`). Worth re-verifying before trusting the comment. If it reproduces, file it — this repo is clearly already a contributor there (#463 is ours), so it's the cheapest path to a fix.

Separately, and independent of any provider bug: the commented OpenVPN block references `data.unifi_radius_profile.default`, which the `system` module never declares (§10). It won't resolve as written even once uncommented.

### 14.7 The commented-out "provider doesn't support this yet" blocks

| Block | Claim | Reality on 2026-09-08 |
|---|---|---|
| `system/etherlighting.tf` + the `ether_lighting` block in `usw_pro_max_24_poe.tf` | "no native resource, PR #463" | ✅ Accurate. [#463](https://github.com/ubiquiti-community/terraform-provider-unifi/pull/463) still **OPEN** since 2026-08-31. |
| `system/mdns.tf` | "no `unifi_setting_mdns` for granular filtering" | ✅ Still accurate — nothing upstream addresses it. Live was brought to the documented Custom scope on 2026-09-13, so the block is now a faithful runbook rather than an aspiration. |
| `system/slas.tf` | "no `unifi_wan_sla`, PR in progress: N/A" | ✅ Still accurate, still nothing upstream. |
| `system/settings.tf` — `unifi_setting_switch` / `unifi_setting_security` | "no native support for Global Switch Settings / Default Security Posture" | ✅ Accurate. Note [#476](https://github.com/ubiquiti-community/terraform-provider-unifi/issues/476) shows even per-device `stp_version`/`stp_priority` don't persist, so STP is unmanageable from either direction right now. |

All four are honest. Worth adding the check date to each so they can be re-audited without re-deriving.

### 14.8 FIXMEs that are now stale

1. **`devices/u7_pro_living_room.tf`** — "the U7-Pro AP is currently physically offline or unadopted … remove this `ignore_changes` once it is plugged in". It **is** adopted and online (`state = 1`, static 192.168.1.4). *But* — `disabled` is one of the fields `buildMinimalUpdateDevice` drops (§14.2), so removing the ignore may just trade one error for another. Remove it and see, but don't be surprised.
2. **LED override is manageable now.** [#337](https://github.com/ubiquiti-community/terraform-provider-unifi/issues/337) (`unifi_device` LED updates fail with inconsistent result) was **fixed in v0.54.0** — `led_override*` is in the minimal PUT, and the update path re-asserts the planned values because the controller applies LED changes to APs asynchronously. So the §3.1 finding (both APs report `led_override = "on"` despite your checklist saying you disabled them) **is codifiable today**: add `led_override = "off"` to both AP resources.
3. **`unifi_network.multicast_dns`** — [#282](https://github.com/ubiquiti-community/terraform-provider-unifi/issues/282) fixed in v0.54.0: the corporate read path now preserves the configured value, falling back to the controller only when unset. Some UniFi OS gateways ignore per-network `mdns_enabled` entirely and always store `false`. Confirmed empirically on 2026-09-13: with the site-wide setting at `all` every network reported `true`; after scoping it to Main + IoT, exactly those two report `true`. The per-network flag is derived from the site-wide scope, so `core/networks.tf` should simply mirror it.

### 14.9 Things to know before touching the firewall (§7)

- **`unifi_firewall_policy.index` is read-only as of v0.54.0** ([#348](https://github.com/ubiquiti-community/terraform-provider-unifi/issues/348)). Ordering **cannot** be managed: `index` is a per-zone-pair controller-assigned ordinal, the integration API rejects it as input, the v2 endpoint ignores it and appends, and the UI's drag-to-reorder uses a private `batch-reorder` endpoint that 500s under API-key auth. Our `allow_main_to_iot` policy will land wherever the controller puts it. [#473](https://github.com/ubiquiti-community/terraform-provider-unifi/pull/473) (open) refreshes the assigned index on read.
- **Guest purpose is coupled to the zone** ([#276](https://github.com/ubiquiti-community/terraform-provider-unifi/issues/276), v0.54.0): on zone-based-firewall controllers a network only keeps `purpose = "guest"` while it belongs to the guest/Hotspot zone; placed elsewhere the controller rewrites it to `corporate`. Our `unifi_network.guest` declares `purpose = "guest"` but **nothing in code manages the Hotspot zone** (§7.1). That's not just a completeness gap — it's load-bearing for the network's purpose surviving an apply. Add the Hotspot zone resource.
- [#472](https://github.com/ubiquiti-community/terraform-provider-unifi/issues/472) (open): `match_mac` isn't exposed and updates silently reset it. [#461](https://github.com/ubiquiti-community/terraform-provider-unifi/pull/461) (open) adds the invert toggles.

### 14.10 Suggested sequencing

Given the above, the ordering that avoids wasted work:

1. **Now, safe:** delete `system/clients.tf`; delete the `config_network = { type = "dhcp" }` block on the Pro Max (latent failure); fix the port profile names/attributes (§2 — `unifi_port_profile` is unaffected by the device-update bug); drop the VLAN 11 network + its output; fix the port-forward name/IP; add `led_override = "off"` to the APs; add the Hotspot zone; delete the dead `radius_profile_secret` and `network_default_id` plumbing.
2. **Now, but as documentation only:** correct the port_override blocks in `devices/*.tf` to match live. They won't apply while `ignore_changes` is on, but they stop the files actively lying.
3. **Blocked on v0.56.0:** removing any `ignore_changes = [port_override]`; static mgmt IPs via `config_network`; re-adding `unifi_client` resources; `wlan_bands` without the ignore.
4. **Blocked indefinitely / manual runbook:** UniFi OS updates schedule, InnerSpace, mDNS granular filtering, WAN SLA, global switch settings, firewall policy ordering, per-device STP.
5. **Worth filing upstream:** the OpenVPN `unifi_vpn_server` behaviour (§14.6), if it still reproduces.

### 14.11 Watchlist

Open items to re-check when v0.56.0 lands:

| # | Type | Title |
|---|---|---|
| [#463](https://github.com/ubiquiti-community/terraform-provider-unifi/pull/463) | PR | etherlighting + device update payload truncation *(ours)* |
| [#470](https://github.com/ubiquiti-community/terraform-provider-unifi/pull/470) | PR | port_profile: keep an explicitly empty `port_security_mac_address` *(ours)* |
| [#473](https://github.com/ubiquiti-community/terraform-provider-unifi/pull/473) | PR | firewall-policy: refresh controller-assigned index |
| [#477](https://github.com/ubiquiti-community/terraform-provider-unifi/pull/477) | PR | network: collapse duplicate DHCP NTP servers |
| [#466](https://github.com/ubiquiti-community/terraform-provider-unifi/pull/466) | PR | site_to_site_vpn: tunnel IP + dynamic subnets in update PUT |
| [#461](https://github.com/ubiquiti-community/terraform-provider-unifi/pull/461) | PR | firewall_policy: expose `match_opposite_*` |
| [#478](https://github.com/ubiquiti-community/terraform-provider-unifi/pull/478) | PR | attribute nesting in objects |
| [#476](https://github.com/ubiquiti-community/terraform-provider-unifi/issues/476) | issue | device: `stp_priority` dropped from update PUT |
| [#475](https://github.com/ubiquiti-community/terraform-provider-unifi/issues/475) | issue | request for a release with the August fixes |
| [#472](https://github.com/ubiquiti-community/terraform-provider-unifi/issues/472) | issue | firewall_policy: expose `match_mac` |
| [#464](https://github.com/ubiquiti-community/terraform-provider-unifi/issues/464) | issue | wlan: null passphrase on open/guest wifi |
