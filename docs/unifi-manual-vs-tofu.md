# UniFi: manual rebuild vs. OpenTofu config — drift report

**Date:** 2026-09-08 (drift analysis) · **Updated:** 2026-09-08 (first remediation pass) · 2026-09-13 (RADIUS users verified in sync; mDNS scoped to Main + IoT)
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
| Port profiles | 🔧 Both live profiles renamed + corrected in code; 802.1X DHCP problem **fixed live**; other 3 profiles ⏳ TODO |
| Device names & IPs | 🔧 Code updated (UDM StKr, static IPs, LEDs off) — but static IPs are 🚫 blocked on provider until v0.56.0 |
| Port overrides | ⏳ TODO (§3.2–§3.4), banner comments added to all three device files |
| WANs | ✅ Code now reflects live |
| Wireless | ✅ All 3 diffs applied to the live controller from code |
| RADIUS / 802.1X | 🔧 Secret now wired into `unifi_setting.radius`; global 802.1X 🚫 not expressible; **all 4 users ✅ live, matching code, and in Vault (2026-09-13)** |
| Firewall | ✅ Hotspot zone + `Dmz` casing in code; policy **created live** |
| Port forwards | ⏳ TODO |
| Fixed-IP clients | ⏳ TODO (and 🚫 blocked — see §14.5) |
| VPN | ⏳ TODO |
| Site settings | ⏳ TODO |
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
| The other 3 port profiles (§2) | `TODO(port-profiles)` banner in `core/port_profiles.tf` |
| Port overrides (§3.2–§3.4) | `TODO(port-overrides)` banners; also 🚫 blocked, see §14.3 |
| **Pro Max ports 6 and 18** | Known-bad, **deferred by the user — do not touch.** Target state recorded in §3.4 and in the browser change log |
| RADIUS users `vl.penchev`, `v.todorova` (§6.3) | ✅ **Created live 2026-09-13, verified identical to code.** Vault `unifi/radius/users` entries confirmed. Only the `tofu import` of the four live accounts remains (see §6.3) |
| Port forwards (§8) onwards | Deferred |
| Static device IPs actually taking effect | 🚫 blocked on upstream #463 — declared but inert, see §14.2 |

---

## 1. Networks / VLANs

### Live

| Name | Purpose | VLAN | Subnet | DHCP | mDNS |
|---|---|---|---|---|---|
| Vivacom Primary | wan (`WAN`) | – | – | – | – |
| Vivacom Secondary | wan (`WAN2`) | – | – | – | – |
| **UniFi Devices** | corporate | untagged | 192.168.1.1/24 | .6–.254 | on |
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

### Live — only two exist

| Name | forward | native | PoE | 802.1X | tagged | STP port mode | autoneg |
|---|---|---|---|---|---|---|---|
| **UniFi Device** | all | UniFi Devices (untagged) | auto | `force_authorized` | auto | true | true |
| **Host Device** | customize | Guest (VLAN 3) | auto | `auto` | auto | true | true |

### Code — five exist (`core/port_profiles.tf`)

| Resource | Name | native | 802.1X | STP port mode |
|---|---|---|---|---|
| `unifi_devices` | UniFi Device**s** | default LAN | `auto` | true |
| `main` | Main | **Guest** | `auto` | **false** |
| `public_servers` | Public Servers | Public Servers | `force_authorized` | false |
| `private_servers` | Private Servers | Private Servers | `force_authorized` | false |
| `iot` | IoT | IoT | `force_authorized` | false |

### Differences

1. **`unifi_devices` → live "UniFi Device"** (singular). Also `dot1x_ctrl`: code `auto`, live `force_authorized`. Everything else matches.
2. **`main` is really the live "Host Device"** — same idea (native = Guest so unauthenticated ports land in Guest, 802.1X `auto` moves them to Main on success), but two diffs: the **name** (`Main` vs `Host Device`) and **`stp_port_mode`** (code `false`, live `true`). Live `true` is what the "Port Mode: Edge" toggle produces, which is what the checklist asked for — so the code value is wrong.
3. **`public_servers`, `private_servers` and `iot` profiles do not exist live.** Nothing on the switches references a per-VLAN profile any more; the two remaining server/IoT ports use inline native-VLAN overrides instead (§3). Their outputs in `core/outputs.tf` and the matching `devices/variables.tf` entries are dead weight unless you recreate them.

---

## 3. Devices, names, IPs and port overrides

### 3.1 Device identity

| MAC | Live name | Live mgmt IP | Code name (`devices/*.tf`) | Diff |
|---|---|---|---|---|
| `28:70:4e:5c:b4:b2` | **UDM StKr** | WAN DHCP | `Dream Machinacho Pro Max` | **name** |
| `9c:05:d6:e2:6b:1d` | USW Pro Max 24 PoE | **static 192.168.1.2** | USW Pro Max 24 PoE | code sets `config_network = { type = "dhcp" }` |
| `1c:6a:1b:98:38:ee` | USW Aggregation | **static 192.168.1.3** | USW Aggregation | code declares no `config_network` |
| `9c:05:d6:d9:ad:79` | Living Room U7-Pro | **static 192.168.1.4** | Living Room U7-Pro | code declares no `config_network` |
| `9c:05:d6:d9:af:65` | Bedroom U7-Pro | **static 192.168.1.5** | Bedroom U7-Pro | code declares no `config_network` |

> **⚠️ The `config_network` column is a trap — see §14.2.** At v0.55.0 `config_network` is dropped from the device update `PUT`, so the static IPs **cannot be codified**. And the existing `config_network = { type = "dhcp" }` on `usw_pro_max_24_poe` is a latent guaranteed apply failure against the live static `.2`. Delete it; don't extend the pattern.

Also:

- The controller itself is named **UDM StKr** (`super_identity.name`), hostname `UDM-StKr`. The checklist step is done; nothing in code manages it.
- **LED override:** both APs report `led_override = "on"` — i.e. LED forced **on**, not disabled. The checklist says "Disable LED on the Living Room and Bedroom APs". Either that step didn't take or it was reverted. Worth re-checking in the UI. The code has no `led_override` attribute at all either way. **This one is fixable today** — upstream #337 landed in v0.54.0, so `led_override = "off"` works on both APs (§14.8).
- `devices/u7_pro_living_room.tf` still carries `lifecycle { ignore_changes = [disabled] }` with a FIXME about the AP being offline/unadopted. It is adopted and online (`state = 1`) now, so that block can go.
- All three `lifecycle { ignore_changes = [port_override] }` blocks (UDM, USW Aggregation, USW Pro Max) are still in place for the provider port-disable crash. As long as they stay, **none of the port drift in §3.2–§3.4 will ever be reconciled by an apply** — the code is documentation only. **Keep them** until v0.56.0: upstream #430 (merged, unreleased) shows a single declared `port_override` silently strips settings from *every* port on the device, which is very likely what flattened these switches in the first place (§14.3).

### 3.2 UDM StKr

| Port | Live | Code |
|---|---|---|
| 1 | *no override* | `Port 1`, customize, native = **WAN2** |
| 2–8 | *no override* | `Port N`, `forward = disabled`, `poe_mode = off` |
| 9 | *no override* | `Port 9`, customize, native = **WAN1** |
| 10 | `SFP+ 1`, profile **UniFi Device** | `SFP+ 1`, profile **Private Servers** |
| 11 | `SFP+ 2`, profile **UniFi Device** | `USW-Aggregation`, profile UniFi Devices |

- Checklist ("UDM StKr ports 10 and 11 → UniFi Device") matches live. Code has port 10 on the wrong profile and a different name on port 11.
- Ports 1 and 9 are the WAN ports per the checklist, but live has **no port override** for them — WAN-to-port binding is handled by the UniFi OS WAN configuration, not by a `port_override` with `native_networkconf_id`. The code's approach here is almost certainly wrong and is what a `wan_primary_id`/`wan_secondary_id` plumb-through in `main.tf` exists to feed.
- The disabled-port block for 2–8 has no live counterpart — **and never worked**: `forward = "disabled"` alone does not disable a port (§14.3).

### 3.3 USW Aggregation

| Port | Live | Code |
|---|---|---|
| 1 | `SFP+ 1`, **manual/customize**, native = Private Servers, 802.1X `force_authorized`, STP edge enabled + BPDU guard | `Servacho-Gosho`, profile Private Servers |
| 2–7 | *no override* | `SFP+ N`, `forward = disabled`, `poe_mode = off` |
| 8 | `SFP+ 8`, profile **UniFi Device** | `UDM-Pro-Max`, profile UniFi Devices |

- Port 1 carries Servacho-Gosho (the 192.168.5.10 client uplinks here). Live uses an **inline** native-VLAN override; code uses a **profile** that no longer exists.
- Port names differ on both ports 1 and 8.
- The 2–7 disabled block has no live counterpart — **and never worked** (§14.3).
- **The checklist doesn't mention configuring aggregation port 1 at all** — it only lists port 8. Undocumented manual step.

### 3.4 USW Pro Max 24 PoE

Live, grouped:

| Ports | Live assignment | Live names |
|---|---|---|
| 1–11, 13–18, 20–22 | profile **Host Device** | default (`Port N`) |
| 19 | **manual/customize**, native = **Main** | `Port 19` |
| 23, 24 | profile **UniFi Device** | `Port 23`, `Port 24` |
| 26 | profile **UniFi Device** | `SFP+ 2` |
| 12, 25 | *no override* | – |

Differences vs. `devices/usw_pro_max_24_poe.tf`:

1. **No custom port names exist live.** Every one of the code's names — `LR-01`…`LR-06`, `Balc-01/02`, `K-01/02`, `BR-01`…`BR-08`, `LR-WiFi`, `BR-WiFi`, `Servacho-Gosho-JetKVM`, `SFP+ 1`, `UDM-Pro-Max` — is gone. All ports are back to `Port N` / `SFP+ N`.
2. **Ports 9, 10, 11** — code disables them (`forward = disabled`, `poe_mode = off`); live has them on Host Device. Note the code's disable never took effect (§14.3).
3. **Port 6** — code assigns the IoT profile; live has Host Device.
4. **Port 12** — code assigns the Private Servers profile (`Servacho-Gosho-JetKVM`); live has no override at all.
5. **Port 18** — code sets an inline native VLAN of Public Servers; live has Host Device.
6. **Port 20** — code assigns the Public Servers profile; live has Host Device.
7. **Port 19** — code assigns the Main profile; live is a **manual** override with native VLAN Main (no profile).
8. **Port 25** — code declares a bare `forward = customize` override; live has none.
9. Ports 23, 24, 26 → UniFi Device matches the checklist and live; only the names differ.

> **Ports 6 and 18 — target state confirmed, fix deferred (2026-09-08).** Both currently sit on `Host Device` and hold no DHCP lease. The user has confirmed the intended configuration and asked that **nothing be changed on either port for now**:
>
> | Port | Currently | Should be |
> |---|---|---|
> | 6 | Host Device, client on VLAN 2, no IP | **IoT (VLAN 6)** — matches the code (`LR-06`), controller is the odd one out |
> | 18 | Host Device, client on VLAN 3 via 802.1X fallback, no IP | **Private Servers (VLAN 5), fixed IP `192.168.5.23`** — the code says Public Servers, so **the code is wrong too** |
>
> The `192.168.5.23` reservation is for `30:52:53:0d:1a:68`, a third JetKVM not present in `system/clients.tf` (which pins `.20` and `.21`). Adding it is blocked on §14.5.

**Checklist vs. live discrepancy:** the checklist says Host Device was applied to "1-5, 7-11, 13-17, 19-22". Live is **1–11, 13–18, 20–22**. Concretely: ports **6** and **18** also got Host Device (not in your list), and port **19** did *not* — it is a hand-rolled native-VLAN-Main override instead. Worth deciding which is intended before codifying.

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
| Internal | UniFi Devices, Main, Private Servers, IoT, Qoax VPS, FMI{Codes} VPS |
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

### Differences

| Code resource | Status |
|---|---|
| `nginx_proxy` — "Personal Server Nginx Proxy Manager", → **192.168.5.102** | **Name and target IP both differ** from the live "NGINX Server" → 192.168.5.58 |
| `fmicodes_db` — 5432 → 192.168.5.200:5432 | **missing live** |
| `fmicodes_ssh` — 2242 → 192.168.5.200:22 | **missing live** |
| `fmicodes_ssh_worker` — 2243 → 192.168.5.201:22 | **missing live** |
| `minecraft_server` (`count = 0`) | inert, matches live absence ✅ |
| `fmicodes_intercom` (`count = 0`) | inert, matches live absence ✅ |

An apply as-is would rename the NGINX rule, repoint it at `.102`, and add the three fmicodes rules back.

---

## 9. Fixed-IP clients (`system/clients.tf`)

### Live — four fixed IPs

| Name | MAC | IP |
|---|---|---|
| `fmicodes-master-node` | `bc:24:11:c3:e5:f4` | 192.168.5.200 |
| `fmicodes-worker-node-1` | `bc:24:11:23:76:b5` | 192.168.5.201 |
| `hackjamhub-intercom` | `bc:24:11:8a:b7:98` | 192.168.5.215 |
| *(unnamed)* | `38:05:25:30:79:97` | 192.168.5.10 — this is Servacho-Gosho, last seen on USW Aggregation port 1, Private Servers |

> **⚠️ Don't rewrite this file yet — see §14.5.** At v0.55.0 *every* in-place `unifi_client` update fails with `inconsistent result after apply: .last_ip` (#428, fixed on `main`, unreleased). Deleting `system/clients.tf` and re-adding it after v0.56.0 is cleaner than porting it to the live four.

### Differences

1. **All ten `unifi_client` resources in code are stale.** None of `MICHELANGELO`, `jetkvm`, `SAMI-DEV-MACHINE`, `rpi-petacho`, `networkboot-server`, `tsb-mint`, `DJAM-11`, `nixos`, `minecraft-fabric-server` or `Servacho-Gosho-JetKVM` exist on the rebuilt controller. This is the single biggest block of dead config.
2. **None of the four live fixed IPs are in code**, including `hackjamhub-intercom` (which isn't on the checklist either — undocumented manual step).
3. **MAC mismatch for Servacho-Gosho.** The checklist says "Set Servacho-Gosho IP to 192.168.5.10", and live has `38:05:25:30:79:97` → `.10`. Code's closest entries are `servacho_gosho_jetkvm` (`38:52:53:0a:09:87` → 192.168.5.20) and `jetkvm` (`30:52:53:08:45:16` → 192.168.5.21) — different MACs, different IPs. Note `192.168.5.10` is also the Proxmox endpoint hardcoded in `tofu/providers.tf`.
4. The live client is **unnamed** — you set the fixed IP but never gave it a name.
5. Live fixed IPs are plain `fixed_ip` on the client object with **no `network_id` binding**; code sets `network_id` on every client.

---

## 10. VPN (`system/vpn.tf`)

- **No VPN server of any kind exists live.** The `Vpn` firewall zone is empty.
- Code declares `unifi_vpn_server.wireguard`. Your uncommitted working-tree change renames it `StKr WireGuard Server` → `.StKr WireGuard Server` and moves the subnet `192.168.7.1/24` → `192.168.8.1/24`. Neither version has been applied.
- The OpenVPN server block remains commented out with its `CustomizeDiff` FIXME. **That FIXME has no upstream issue and its wording is suspect** — `CustomizeDiff` is SDKv2 vocabulary and this is a plugin-framework provider (§14.6). Re-verify, then file it. It references `data.unifi_radius_profile.default`, which is **not declared in the `system` module** (it's declared in `wireless/data.tf` and `security/radius.tf`) — uncommenting it as-is won't even parse-resolve.
- The checklist doesn't mention setting up a VPN, so this is code-ahead-of-reality, not drift.

---

## 11. Site settings (`system/settings.tf` and friends)

| Setting | Live | Code | Diff |
|---|---|---|---|
| Country | `100` (Bulgaria) | `100` | ✅ |
| NTP | `setting_preference = auto` | same | ✅ |
| IGMP snooping | `enabled = false` | `enabled = false` | ✅ |
| **Auto speedtest** | **setting key absent entirely** | `enabled = true`, `cron_expr = "0 4 * * *"` | code would create it |
| Updates schedule | `mgmt.auto_upgrade = true`, `auto_upgrade_hour = 3`, no weekday | not managed | **unmanaged** |
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
4. **`port_profile_public_servers_id` / `port_profile_iot_id`** — each used exactly once (ports 20 and 6 of the Pro Max), both of which are Host Device live. If you drop those profiles, drop the plumbing too.
5. **Three `ignore_changes = [port_override]` blocks** — until upstream PR #470 *and* the unreleased #430/#438 land, every port assignment in `devices/*.tf` is decorative. Anything you "fix" there today has no effect on the controller (§14.3).
   - The FIXME text itself is worth updating: it blames "a bug parsing the empty MAC allowlist required for the new UniFi OS Port State toggles", which is #470 and correct — but omits that `forward = "disabled"` was never the right mechanism, and that #430 (whole-array replacement stripping undeclared ports) is the more dangerous of the two.
6. **`system/vpn.tf`** OpenVPN block references `data.unifi_radius_profile.default`, which the `system` module never declares.
7. Untracked working-tree changes: trailing-newline cleanup in `core/port_profiles.tf`, and the WireGuard rename + subnet move in `system/vpn.tf`.

---

## 13. Live-only, undocumented manual steps

Things the controller has that are on neither the checklist nor in code:

- **USW Aggregation port 1** — manual override, native VLAN Private Servers, 802.1X `force_authorized`, STP edge + BPDU guard (Servacho-Gosho's uplink).
- **USW Pro Max port 19** — manual override, native VLAN Main, no profile.
- **USW Pro Max ports 6 and 18** — on Host Device, though the checklist excludes them.
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

> **⚠️ Correction to §3.1.** My earlier suggestion to add `config_network` blocks with the static IPs (.2/.3/.4/.5) **will not work** on the pinned provider — it'll fail with an inconsistent-result error on every apply. Worse, `devices/usw_pro_max_24_poe.tf` **already declares `config_network = { type = "dhcp" }`** while the switch is live on a static `192.168.1.2`. That is a latent guaranteed apply failure sitting in the tree right now. Delete that block (or accept the drift and document it) rather than extending the pattern. Fix is in open PR [#463](https://github.com/ubiquiti-community/terraform-provider-unifi/pull/463), which adds `config_network`, `lcm_brightness` and `outlet_enabled` to the builder — but *not* the STP fields.

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

Combined with §9 (all ten client resources are stale, four live fixed IPs unmanaged), this argues strongly for **deleting `system/clients.tf` entirely for now** rather than rewriting it against the live four. Re-add it after v0.56.0. Also unreleased: clearing `fixed_ip` ([#400](https://github.com/ubiquiti-community/terraform-provider-unifi/pull/400)).

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
