# UniFi: manual rebuild vs. OpenTofu config — drift report

> **Layout note (2026-09-14).** The module was flattened: the `core/`, `devices/`, `security/`, `system/` and `wireless/` submodules are gone and every file now sits directly in `tofu/unifi/` (`networks.tf`, `device_*.tf`, `firewall.tf`, `settings.tf`, …; inputs, provider pin and shared data sources in `module.tf`). See `tofu/unifi/README.md` for the map. Text dated before 2026-09-14 may still use the old paths: `core/X.tf` → `X.tf`, `devices/X.tf` → `device_X.tf`, `security/X.tf` / `system/X.tf` / `wireless/X.tf` → `X.tf`; `system/etherlighting.tf` → `settings.tf`, `system/slas.tf` → `wans.tf`; the per-module `variables.tf` / `versions.tf` / `data.tf` / `outputs.tf` no longer exist.

**Date:** 2026-09-08 (drift analysis) · **Updated:** 2026-09-08 (first remediation pass) · 2026-09-13 (RADIUS users verified in sync; mDNS scoped to Main + IoT; per-VLAN port profiles recreated; all port overrides aligned live and in code, UI-only fields marked FIXME) · **2026-09-14** (module flattened; VPN servers, console settings, admins, client names, alarm audit; **management VLAN migration finished** — all four devices on VLAN 99, trunks native 99, Default DHCP off; open items consolidated in §0.6) · **2026-11-02** (provider 0.65.0: statuses in §0, §0.6 B, §8 and §14; what is still not in code in §15; Global Switch Settings in code, §6 and §11)
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
| Device names & IPs | ✅ Code matches live incl. static IPs and LEDs. Since provider 0.58.0 an update sends `config_network` (upstream #482), so an address changed in code reaches the controller; it is still changed in the UI first |
| Port overrides | ✅ **All three devices aligned 2026-09-13** — live changed to the code's intent and code rewritten to the stored shape (§3.2–§3.4); every provider-expressible field declared, every UI-only field carries a `FIXME(unifi-ui-only)`. Still not reconciled by apply: the `ignore_changes` stay at provider 0.65.0 (§14.3, §15) |
| WANs | ✅ Code now reflects live |
| Wireless | ✅ All 3 diffs applied to the live controller from code |
| RADIUS / 802.1X | 🔧 Secret now wired into `unifi_setting.radius`; global 802.1X port control managed as `unifi_setting.global_switch` (§11), the fallback VLAN 🚫 still set by hand (§15); **all 4 users ✅ live, matching code, and in Vault (2026-09-13)** |
| Firewall | ✅ Hotspot zone + `Dmz` casing in code; policy **created live** |
| Port forwards | ✅ Two rules since #85 (2026-11-02): `Unity Intercom` and `os-tues SSH`, both created by apply (§8) |
| Fixed-IP clients | ✅ `clients.tf` mirrors the live reservations, attribute-exact, **all named** (8 on 2026-09-13, 12 since 2026-10-14). In-place updates work since provider 0.56.0, but changes still go UI first; never declare `network_id` (§14.5) |
| VPN | ✅ Teleport (UI-only, FIXME) + OpenVPN + WireGuard live and mirrored 2026-09-13; WireGuard peers still to add (§10) |
| Module layout | ✅ **Flattened 2026-09-14**: five submodules → one module, topic-named files, `module.tf` for inputs/provider/shared data, `README.md` map. No state existed, so no `moved` blocks were needed |
| Site settings | ✅ `mgmt` + `lcm` blocks added from the Console page and auto speedtest set live 2026-09-13; UniFi OS-only items incl. admins and Alarm Manager carry `FIXME(unifi)` (§11) |
| **Management VLAN** | ✅ **Finished 2026-09-14** — UDM, both switches and both APs manage on **UniFi Devices, VLAN 99** (static `.99.2–.99.5`), the UniFi Device profile is native 99, Default (Untagged) has DHCP off. Full story incl. the AP-vs-switch override rule in `unifi-mgmt-vlan-99-runbook.md` |
| **State** | ✅ **Live controller imported 2026-09-14** — 46 resources in state on the management plane, plan **No changes** (§0.6 A1, [`unifi-import-plan.md`](unifi-import-plan.md)). Code is now the source of record for everything the provider can express |
| **Provider bugs** | **Pinned at 0.65.0 (§14.1).** Most of what the FIXMEs waited for has shipped; §14 keeps the 2026-09-08 analysis with a status per subsection, and **§15 lists every `FIXME`/`TODO` still in the code**. Write hazards 0.55.0 did not have: every `unifi_port_profile` write resets eight unmodelled booleans (since 0.58.0), and `unifi_device_port` (new in 0.65.0) fails every in-place update on OpenTofu 1.11 |

> **Read §14 and §15 before acting on any of this.** The module pins `ubiquiti-community/unifi` `~> 0.65.0` (released 2026-11-01). The device-update path that dropped most configured fields at v0.55.0 sends them since v0.58.0, and the rest of the 2026-09-08 bug surface is re-checked in §14. What is still not in code, and why, is §15.

---

## 0.5 Remediation pass — 2026-09-08

### Changed in code (needs `tofu apply` from the management plane)

| File | Change |
|---|---|
| `networks.tf` | `default` → name **UniFi Devices**; Qoax widened to **`192.168.10.1/23`**, renamed **Qoax VPS**, DHCP `.10.11–.11.254`; **VLAN 11 network deleted**; `TODO(mdns)` markers added; `TODO(vlan1)` note |
| `core/outputs.tf (removed 2026-09-14: the flat layout has no outputs)` | dropped the VLAN 11 output; `port_profile_main_id` → `port_profile_host_device_id` |
| `port_profiles.tf` | `unifi_devices` → name **UniFi Device**, `dot1x_ctrl` → `force_authorized`; `main` → resource **`host_device`**, name **Host Device**, native → **Main**, `stp_port_mode` → `true`, `setting_preference` → `manual`; the other three profiles kept behind a `TODO(port-profiles)` banner |
| `wans.tf` | primary `weight` 50 → **99**; secondary: dropped `weight` and `provider_capabilities` to match live |
| `device_udm_pro_max.tf` | name → **UDM StKr** |
| `device_usw_pro_max_24_poe.tf` | `config_network` dhcp → **static 192.168.1.2** |
| `device_usw_aggregation.tf` | added `config_network` **static 192.168.1.3** |
| `device_u7_pro_living_room.tf` | **static 192.168.1.4**, `led_override = "off"`; stale offline-AP FIXME rewritten |
| `device_u7_pro_bedroom.tf` | **static 192.168.1.5**, `led_override = "off"` |
| `device_*.tf` | `TODO(port-overrides)` banner on all three, incl. the `forward = "disabled"` correction |
| `devices/variables.tf (removed 2026-09-14)`, `main.tf` | dead `network_default_id` removed; `host_device` rename plumbed; `radius_profile_secret` wired into the `system` module |
| `settings.tf` | added `radius = { secret = var.radius_profile_secret, … }`; refreshed the Global Switch Settings note with the 2026-09-08 re-check and the fallback-VLAN dependency |
| `system/variables.tf (removed 2026-09-14)` | accepts `radius_profile_secret` |
| `firewall.tf` | `"DMZ"` → **`"Dmz"`**; added **`unifi_firewall_zone.hotspot`** ← Guest; ordering caveat noted on the policy |
| `security/variables.tf (removed 2026-09-14)` | accepts `network_guest_id` |
| `radius.tf` | `TODO(radius-users)` for `vl.penchev` / `v.todorova` |

`tofu fmt` clean, `tofu validate` passes.

### Changed on the live controller

Six changes — see [`unifi-browser-changes.md`](unifi-browser-changes.md) for the full log. Headline: **the 802.1X fallback VLAN was empty, which is why unauthenticated clients got no DHCP.** It is now Guest.

### Still open

Superseded by **§0.6** below (2026-09-14). Everything in the old table is either ✅ done — mDNS, port profiles, port overrides, Pro Max 6/12/18, RADIUS users, port forwards, fixed-IP clients, VPN servers, site settings, static device IPs, the VLAN 99 migration — or carried over there.

---

## 0.5b Remediation pass — 2026-09-09 *(merged from the remote branch state on 2026-09-14)*

Guest access to the two TVs, plus the last two deferred ports. Intent: Guest (VLAN 3) may reach exactly two IoT devices (the living-room EON box and the bedroom BRAVIA), and IoT may not initiate anything towards Internal.

**The finding that shaped it:** the "Main can reach IoT but not vice-versa" posture was never in force. IoT and Main both sat in the **Internal** zone, whose `Internal → Internal` pair carries the predefined `ALLOW Allow All Traffic` — so IoT → Main was wide open and `allow_main_to_iot` (§7, difference 3) was a no-op with 2,996 hits it never needed to match.

**Corrected mid-implementation.** An earlier draft of this section argued that because `global_network.default_security_posture` is `ALLOW_ALL`, a new zone pair would default to *allow*, so the asymmetry needed an explicit `NEW`-only BLOCK policy. **That was wrong**, and creating the zone proved it: the Create Zone dialog states that *"newly created zones are blocked from accessing all other zones except External and Gateway by default"*, and the live table immediately showed predefined `BLOCK Block All Traffic` on `IoT → Internal` / `Hotspot` / `Vpn` / `Dmz` at index 2147483647, with `IoT → External` and `IoT → Gateway` (plus `Allow mDNS`) left allowed. `ALLOW_ALL` governs the built-in zones' predefined policies, not user-created ones. So the asymmetry comes from the zone boundary itself, **no BLOCK policy was created**, and the three ALLOWs at index ~10000 sit far ahead of the catch-all block — ordering is not in question.

### Changed in code (needs `tofu apply` from the management plane)

| File | Change |
|---|---|
| `core/port_profiles.tf` | three per-VLAN profiles renamed to the live singular convention — **Public Server**, **Private Server**, **IoT Device**; `TODO(port-profiles)` banner resolved, replaced with the intended port assignments; `TODO(port-security)` added for the eventual MAC allowlist (blocked on #470 — an empty allowlist errors every apply, so only declare it with real MACs) |
| `core/networks.tf` | `multicast_dns = true` on all eight networks to match live; the six `TODO(mdns)` markers closed |
| `security/firewall.tf` | added **`unifi_firewall_zone.iot`** ← IoT; added **`unifi_firewall_group.tv_media_endpoints`** (`192.168.6.10`, `.11`); added **`allow_private_servers_to_iot`** and **`allow_guest_to_tvs`** (destination via `ip_group_id`); retargeted `allow_main_to_iot`'s destination to the IoT zone. **No BLOCK policy** — the predefined zone default covers it, with the reasoning recorded in-file so it is not "simplified" back |
| `security/variables.tf`, `main.tf` | `security` module accepts `network_private_servers_id` |
| `devices/usw_pro_max_24_poe.tf` | **port 18**: inline native VLAN Public Servers → `port_profile_id = var.port_profile_private_servers_id`, with a note that `ignore_changes` means it records intent only |
| `devices/variables.tf`, `main.tf` | `network_public_servers_id` dropped from the `devices` module — port 18 was its only consumer |
| `system/mdns.tf` | the fictional `unifi_setting_mdns` block deleted; replaced with a `FIXME(unifi)` recording live state and the two-repo upstream PR required |

`tofu fmt` clean, `tofu validate` passes against the pinned v0.55.0 schema — which also confirms `ip_group_id` exists at our pin. Live confirmed the provider's derivation too: the Guest→TVs destination reads back as `matching_target = IP` with `matching_target_type = OBJECT`, exactly what #365 fixed.

### Changed on the live controller

**All applied 2026-09-09** through the admin panel — full log in [`unifi-browser-changes.md`](unifi-browser-changes.md). Three port profiles created (`Public Server` / `Private Server` / `IoT Device`, all Force Authorized, all set to Port Mode **Edge**), applied to ports 6 and 18; three fixed IPs reserved; the `IoT` zone created (`6aa12f7b40324b4491452cf5`); the `TV Media Endpoints` address group created (`6aa1316d40324b4491452f98`); `Allow Main to IoT` retargeted and un-paused; `Allow Private Servers to IoT` and `Allow Guest to TVs` created. The Gateway mDNS Proxy was deliberately left untouched. **The address group and `Allow Guest to TVs` were both deleted again on 2026-09-11 — see the warning below.**

Because these were created by hand, the matching resources need importing before any apply — notably the IoT zone by **ID**, since a custom zone cannot be imported by name the way the built-in Hotspot/Internal zones can:

```
tofu import unifi_firewall_zone.iot 6aa12f7b40324b4491452cf5
```

Two items needed a physical action on the device and could not be done from the controller. **Both are now resolved.** The **EON box** was power-cycled by the user on 2026-09-09 and came up on `192.168.6.10` (neither port 6 nor 18 draws PoE, so no controller-side power cycle was possible). The **BRAVIA's randomized MAC** was turned off on 2026-09-10; that swapped it to the hardware `f4:4e:b4:73:bf:19` and orphaned the reservation, which was re-pointed the same day — the TV now holds `192.168.6.11`. Both TVs are on their reserved addresses.

> **⚠️ Guest access to the TVs was abandoned on 2026-09-11** and both the `Allow Guest to TVs` policy and the `TV Media Endpoints` group were deleted from the controller and from the code. The zone firewall is **not** the enforcement point for a guest network: UniFi's access points drop guest traffic to other VLANs locally, ahead of any policy, so a correct ALLOW sat there and matched exactly zero packets. Everything else from this work — the IoT zone, the two remaining ALLOW policies, the port profiles, ports 6 and 18, the reservations — stands. Full write-up in [`unifi-browser-changes.md`](unifi-browser-changes.md).

### Decisions recorded

| Question | Decision |
|---|---|
| Move Home Assistant (`192.168.5.226`) to IoT? | **No — stays on Private Servers (VLAN 5).** The zone firewall only sees inter-VLAN traffic, so co-locating HA with the devices it holds credentials for would put its admin UI and tokens in front of every bulb and TV with nothing able to filter it. If an integration needs to be on-link, give HA a second VLAN-6-tagged interface for discovery instead of relocating it. mDNS-based discovery (ESPHome, Chromecast, HomeKit) already crosses VLANs via the proxy; SSDP/UPnP does not, so those integrations need static IPs |
| Tighten the Gateway mDNS Proxy? | **No — stays `mode: all` / `enabled_for: all`.** Discovery from Guest already works; narrowing it is optional hardening, and it is not codifiable anyway (§11) |
| Reserve the TV and JetKVM IPs in code? | **No — controller-only** until v0.56.0, per §14.5. The firewall matches an address group, so no client resource is needed |
| Match the TVs by MAC? | **No — by IP**, and 2026-09-10 vindicated it. The BRAVIA presented a randomized locally-administered MAC (`52:4b:e7:…`); turning randomization off swapped it for the hardware `f4:4e:b4:73:bf:19`, which orphaned the DHCP reservation but left the firewall policy untouched — exactly the failure mode matching by IP was chosen to avoid |
| Flip `default_security_posture` to deny? | **No.** Site-wide, it would re-gate every existing zone pair; the `NEW`-only BLOCK gets the asymmetry without that blast radius |

### Still open

| Item | Why |
|---|---|
| Everything controller-side | Pending manual steps — see the checklist in the browser change log |
| MAC filtering on the server port profiles | `TODO(port-security)`; blocked on #470 |
| `stp_edge_state` (Port Mode Edge/Infrastructure) | Not exposed by the provider though go-unifi has it — **provider-only PR**. Set by hand on all three new profiles; an apply that recreates them would revert it |
| `Public Server` profile has no port | Ports 20 and USW Aggregation 1 are remaining §3.4 work; port 12 already matches the code |
| ~~Whether Guest discovery of the TVs actually works~~ | **Answered 2026-09-11 — it does, and it did not help.** Discovery worked once `l2_isolation` was off; the unicast stream was still dropped at the AP. See §0.7 |

---

## 0.5c Remediation pass — 2026-09-11 *(merged from the remote branch state on 2026-09-14)*

Guest→TV access abandoned and rolled back, then a code-vs-live audit of everything this branch had accumulated. The controller-side rollback is logged in [`unifi-browser-changes.md`](unifi-browser-changes.md); what follows is the code and process side.

**The finding that ended the feature:** for a guest network the zone firewall is not the enforcement point. Clients of a Hotspot-zone network are flagged `is_guest` and the access points enforce isolation locally, ahead of any zone policy. All three Hotspot → IoT policies read **exactly zero hits** after real cast attempts, while `Allow Main to IoT` carried 13,373 at the same moment — so the packets never reached the gateway at all. A correct, enabled, correctly-ordered ALLOW sat in the policy table and matched nothing, while reading to any observer as though Guest could reach the TVs. **mDNS was never involved**; the reflector was measurably working throughout (337,966 hits).

### Changed in code

| File | Change |
|---|---|
| `security/firewall.tf` | `unifi_firewall_group.tv_media_endpoints` and `unifi_firewall_policy.allow_guest_to_tvs` **removed**, matching the controller. Replaced with a short do-not-reinstate note recording why the design cannot work |
| `wireless/wlans.tf` | **`l2_isolation = true` declared on `stkr_guest`** — see the hazard below. `is_guest = true` kept with a note that live is `false` |
| `system/mdns.tf` | corrected: the earlier text claimed the missing piece was a unicast permission. It records the measured hit counts and that mDNS was never the cause |
| `devices/u7_pro_living_room.tf` | PR #22 merged in; the stale "AP is offline" FIXME rewritten to the real reason the `ignore_changes` stays |
| everywhere | comment volume cut by ~200 lines — session narrative and change logs removed in favour of the docs, FIXMEs and hazard warnings kept |

**The hazard worth recording.** `l2_isolation` was not declared on *any* WLAN. The provider schema makes it `Optional + Computed` with `booldefault.StaticBool(false)` (`unifi/wlan_resource.go:469`), so the next apply would have silently switched Client Device Isolation **off** on the guest SSID — undoing, without a diff anyone would notice, the isolation the rollback had just restored. This is the general shape of the risk in this repo: a Computed attribute left undeclared does not mean "leave it alone", it means "set it to the schema default".

*Corrected 2026-11-02:* at v0.55.0 the default sat at `wlan_resource.go:441-446` (line 469 is `fast_roaming_enabled`), and the plan would have shown it as `l2_isolation = true -> false`, not hidden it. Provider 0.64.0 dropped the default (upstream #680): an undeclared `l2_isolation` now keeps the controller's value on an existing SSID, but a create still sends `false`, so it stays declared for a rebuild.

### Process

| What | Detail |
|---|---|
| Commit hook adopted | `qoax-community/qoax-githooks` as a submodule pinned to `13c0c65`, plus `.githooks/commit-msg`, `scripts/setup-hooks.sh`, dependabot and a CI workflow. **Run `sh scripts/setup-hooks.sh` once after cloning.** Two deviations from the upstream README, both because this repo is outside the qoax-community org: the submodule URL is absolute, and CI calls the public composite action directly rather than the private `qoax-reusables` workflow |
| PRs consolidated | #22 and #30 **merged into #29**, which is now the single open PR for all UniFi work — 30 commits, targeting `main` |
| Commit messages fixed | All 13 non-conforming messages rewritten (5 over-long bodies rewrapped, 8 AI attribution trailers dropped, 2 over-long subjects shortened). Content, author/committer dates and identities verified unchanged; backup at tag `backup/pre-msg-rewrite-a20428a` |

### ⚠️ New finding: CI can reach the controller, and its credential is broken

The `plan` workflow has failed on every run since **2026-09-07**, on both branches, at provider setup:

```
AUTHENTICATION_FAILED_INVALID_CREDENTIALS: Invalid username or password
(403 Forbidden) for POST https://192.168.1.1/api/auth/login
payload: {"username":"servacho-managment-plane"}
```

Almost certainly the factory reset: the local admin the management plane authenticates as was wiped with everything else, so the Vault credential names a user the rebuilt controller does not have.

**The important part is that it is a 403 and not a timeout.** The runner reached the controller and was refused *by it*. CI therefore has a network path to `192.168.1.1` that the workstation does not — which makes it the place a real `tofu plan` can finally be produced. Every "we could not run plan" caveat in this document is a consequence of that path not being usable, and this is the single highest-value thing to fix. The provider's own error message recommends `UNIFI_API_KEY` over username/password, which also sidesteps UniFi's login rate limiting.

---

> The remote branch's §0.8 to-do list (2026-09-11) is superseded by §0.6 below. Of its items, these were still open when merged and are now in §0.6: the **`l2_isolation` hazard and `is_guest` restore on `StKr_Guest`** (B6/A8), the stale local lock file (A9). The IoT zone import is one of the 46 import blocks; the controller credential was recreated 2026-09-13; JetKVM port 12, port forwards, VPN, site settings and the RADIUS users are done.

---

## 0.6 What's left — 2026-09-14

Ordered by what unblocks what. Anything not on this list is done and mirrored.

### A. Can be done now

| # | Item | Where | Notes |
|---|---|---|---|
| A1 | **`tofu import` of every live resource, then a first `tofu plan`** | management plane; [`unifi-import-plan.md`](unifi-import-plan.md) | ✅ **Done 2026-09-14.** Apply run 34843335300 put all 46 objects in state and applied the guest `is_guest` and OpenVPN changes; two updates failed (§14.12 #11, #12) and were resolved in code (#11) and through the API (#12). The UniFi Devices network was then re-imported (apply run 34876118372, `1 imported, 0 changed`) to get past the sticky Read (§14.12 #14). `tofu/imports_unifi.tf` deleted afterwards; the plan on the branch reads **No changes**. From here on the loop is: change in UI/API → read back → mirror → plan clean. The `tofu-apply` environment has **no protection rules** — a dispatch applies immediately. |
| A2 | **WireGuard peers** | `vpn.tf` → `unifi_wireguard_peer` blocks | Server exists live (`192.168.9.1/24`, UDP 51820, key in OpenBao). Decide the peer list (phones, laptop), generate each key pair off-box, put private keys in OpenBao, declare peers with `interface_ip` from `.9.2` up. Public keys are not secret. Create live → read back → mirror, as with the servers. |
| A3 | ~~**Firewall policy `allow_main_to_iot`**~~ | `firewall.tf` | ✅ **Was wrong here: it has existed live since 2026-09-08** (change #6), re-pointed at the custom **IoT zone** when that zone was created on 2026-09-13, 5 200+ hits. A second custom policy, **Allow Private Servers to IoT**, exists as well. Code now mirrors both (`destination` = whole IoT zone, `matching_target ANY`) plus `unifi_firewall_zone.iot`. Ordering stays manual (§14, #348). |
| A4 | ~~Pro Max **port 25**~~ | `device_usw_pro_max_24_poe.tf` | ✅ **Disabled 2026-09-14** (`SFP+ 1 (Disabled)`, copy of port 9's shape); code mirrors live. No port on any device is native VLAN 1 any more. |
| A5 | ~~UDM **port 2 "Console"**~~ | `device_udm_pro_max.tf` | ✅ Re-disabled 2026-09-14 once the laptop was unplugged; code mirrors live. Re-enable it in the UI (Main access) before the next trunk change. |
| A6 | ~~Redundant per-device `flowctrl_enabled` / `jumboframe_enabled` on the Pro Max~~ | `device_usw_pro_max_24_poe.tf` | ✅ Removed 2026-09-14 — both are site-global under `global_switch` (flow control off, jumbo frames off live) and the per-device copies added nothing. |
| A7 | Stale §1 "Differences" 1–3 | this document | Written 2026-09-08; the code has long since had `Default (Untagged)`, no VLAN 11 and the `/23` Qoax network. Struck through below. |
| A8 | ~~**`is_guest` on `StKr_Guest`**~~ ✅ restored to `true` by the first apply (2026-09-14, run 34843335300) | `wlans.tf`, Settings → WiFi | Code says `true`, the remote-branch audit of 2026-09-11 found live `false` (Application was switched away from Hotspot during the guest-TV rollback). Re-check live; if still `false`, the first apply is the safe fix — the UI needs the guest passphrase re-entered, the provider sends the whole object (§0.5c). |
| A9 | ~~Stale local lock file~~ | `tofu/unifi/.terraform.tfstate.lock.info` + 0-byte `terraform.tfstate` | ✅ Deleted from the workstation 2026-09-14. They were git-ignored leftovers of an apply interrupted on 2026-09-04 and never affected CI, which checks out fresh. Real state is on the management plane only. |

### B. Blocked on the provider at v0.55.0 — status at 0.65.0 (2026-11-02)

The fixes these waited for shipped between v0.56.0 and v0.64.0; the last column says what that changed. What is still open is in §15.

| # | Item | Blocked by (at v0.55.0) | Status at 0.65.0 |
|---|---|---|---|
| B1 | Three `lifecycle { ignore_changes = [port_override] }` blocks (UDM, both switches) — every port block is documentation until then | #470 (empty MAC allowlist crash) **and** unreleased #430/#438 (array stripping) | 🔧 The fixes shipped (#430/#438 in v0.56.0, #652 in v0.62.0; #470, v0.57.0, was `unifi_port_profile`'s), but the ignores **stay**. Lifting one is not a no-op: import and refresh never put `port_override` in state, so the first plan adds every block, and the apply writes the whole array unless every entry equals live both ways. The way out is `unifi_device_port`, one import per port, once CI runs OpenTofu >= 1.12 (§14.3, §15). |
| B2 | `config_network` (static mgmt IPs) is read-only in practice | #463 (dropped from the update PUT) | ✅ Sent since v0.58.0 (#482, with #520 for the other device fields), as a whole object whenever it differs from live. Changes still go through the UI first. |
| B3 | `unifi_client` in-place updates always fail | #428 | ✅ Fixed in v0.56.0 (#447). Updates now succeed, so a client diff that reaches main is applied: name or bind a client in the UI first, then mirror. `network_id` is the Network Override, as it already was at v0.55.0 (v0.62.0 documents it so, #653): never declare it on the two network-bound reservations (§14.5). |
| B4 | `wlans.tf` `ignore_changes = [passphrase, wlan_bands, wlan_band]` ×4 | §14.4 | ✅ `wlan_bands`/`wlan_band` dropped from the ignore (no `wlan_band` default since v0.59.0). `passphrase` stays ignored until a plan without it is clean (§15). |
| B5 | `device_u7_pro_living_room.tf` `ignore_changes = [disabled]` | precautionary, §14.2 (`disabled` is also dropped from the PUT) | ✅ Removed. Read maps the missing key to `false`, the declared value, so nothing ever differed. |
| B6 | **`l2_isolation` must stay declared on `StKr_Guest`** | provider schema: Optional+Computed with a `false` default (`wlan_resource.go:441-446`) | ✅ Still declared, for a different reason. v0.64.0 dropped the default (#680): an undeclared `l2_isolation` keeps the controller's value on an existing SSID, but a create sends `false`, so a rebuild would come up with isolation off. At v0.55.0 an undeclared one would have shown as `true -> false`, not without a diff (§0.5c). |

### C. Not expressible — manual runbook items, each carries a `FIXME(unifi)` / `FIXME(unifi-ui-only)` in code

Global Switch Settings without an attribute (802.1X fallback VLAN = Guest, the 802.1X RADIUS profile, L3 network isolation, flow control, auto STP edge detection); the default security posture; per-profile UI fields (Port Mode Edge, BPDU Guard, Flow Control, PTP, Link Debounce, EEE, …); per-port `sd_wan_underlay_port`; WAN-to-port binding; Teleport VPN; OpenVPN protocol/cipher extras; firewall policy ordering; UniFi OS items (admins, Alarm Manager rules, update schedule, InnerSpace); WAN SLA; the APs' *Default (Untagged)* label in the device list (an AP with Network Override off is stored as the Default LAN id, the controller rejects an empty value — cosmetic, no fix). The current list, marker by marker, is §15.

### D. Decisions still open

- ~~**A3** — is Main → IoT supposed to be open?~~ Yes — it already was; Private Servers → IoT too.
- **A2** — which WireGuard peers, and whether OpenVPN stays now that WireGuard exists (it is live and mirrored; keeping it costs nothing).
- ~~**A5** — keep the Console port.~~ Decided: disabled again, enable on demand.

---

## 1. Networks / VLANs

### Live

| Name | Purpose | VLAN | Subnet | DHCP | mDNS |
|---|---|---|---|---|---|
| Vivacom Primary | wan (`WAN`) | – | – | – | – |
| Vivacom Secondary | wan (`WAN2`) | – | – | – | – |
| **Default (Untagged)** *(was UniFi Devices until 2026-09-13; DHCP **off** since 2026-09-14)* | corporate | untagged | 192.168.1.1/24 | — | off |
| **UniFi Devices** *(new 2026-09-13, runbook Phase 0)* | corporate | **99** | 192.168.99.1/24 | .6–.254 | off |
| Main | corporate | 2 | 192.168.2.1/24 | .6–.254 | on |
| Guest | guest | 3 | 192.168.3.1/24 | .6–.254 | on |
| Public Servers | corporate | 4 | 192.168.4.1/24 | .6–.254 | on |
| Private Servers | corporate | 5 | 192.168.5.1/24 | .6–.254 | on |
| IoT | corporate | 6 | 192.168.6.1/24 | .6–.254 | on |
| **Qoax VPS** | corporate | 10 | **192.168.10.1/23** | **.10.11–.11.254** | on |
| FMI{Codes} VPS | corporate | 12 | 192.168.12.1/24 | .6–.254 | on |

### Differences vs. `tofu/unifi/networks.tf`

1. ~~**`unifi_network.default` name.** Code says `"Default"`; live is `"UniFi Devices"`.~~ **Stale.** Both are `Default (Untagged)` since 2026-09-13 (runbook Phase 0); management moved to the new `UniFi Devices` VLAN 99 network, which code declares as `unifi_network.unifi_devices`.
2. ~~**VLAN 11 no longer exists.**~~ **Resolved in code** (the network and its output are gone). Original note: Code declared `unifi_network.qoax_community_broadcast_vps` (VLAN 11, `192.168.11.1/24`). Live has no VLAN 11 — the Qoax network was widened to a **/23** that spans 192.168.10.0–192.168.11.255 instead. `core/outputs.tf (removed 2026-09-14: the flat layout has no outputs)` still exports `network_qoax_community_broadcast_vps_id`.
3. ~~**Qoax network renamed and resized.**~~ **Resolved in code** — `networks.tf` now declares `Qoax VPS`, `192.168.10.1/23`. Original note: Code: `"Qoax Community VPS"`, `192.168.10.1/24`, DHCP `.6`–`.254`. Live: `"Qoax VPS"`, `192.168.10.1/23`, DHCP `192.168.10.11`–`192.168.11.254`.
4. ~~**mDNS is on everywhere.**~~ **Resolved 2026-09-13.** The site-wide Gateway mDNS Proxy was still at the factory `mode: "all"`; it is now `custom`, scoped to **Main + IoT** with 19 services (§11, `mdns.tf`). After that change the controller reports `mdns_enabled = true` on exactly Main and IoT and `false` on the other six — i.e. the per-network flag is *derived from* the site-wide scope (upstream #282). Code now matches: only `unifi_network.guest` changed (`true → false`), and the `TODO(mdns)` markers are gone.
5. Main / Guest / Public Servers / Private Servers / IoT / FMI{Codes} VPS otherwise match exactly (VLAN id, subnet, DHCP range, purpose).

> Checklist note: the checklist lists "Qoax VPS (10)" with no VLAN 11 — so the /23 consolidation was deliberate, and the code is the stale side.

---

## 2. Port profiles

### Live — five exist (updated 2026-09-13)

| Name | forward | native | PoE | 802.1X | tagged | pref | STP (`stp_port_mode`) | Port Mode (`stp_edge_state`) |
|---|---|---|---|---|---|---|---|---|
| **UniFi Device** | customize *(was `all`; the controller rewrites it once native ≠ Default)* | **UniFi Devices (VLAN 99)** *(since 2026-09-14, runbook Phase 4)* | auto | `force_authorized` | auto | auto | true | Infrastructure |
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

### Code — `port_profiles.tf`

| Resource | Name | native | 802.1X | pref | `stp_port_mode` |
|---|---|---|---|---|---|
| `unifi_devices` | UniFi Device | default LAN | `force_authorized` | (auto) | true |
| `host_device` | Host Device | Main | `auto` | manual | true |
| `public_servers` | Public Server | Public Servers | `force_authorized` | manual | true |
| `private_servers` | Private Server | Private Servers | `force_authorized` | manual | true |
| `iot` | IoT Device | IoT | `force_authorized` | manual | true |

### Differences

**None as of 2026-09-13** for anything `unifi_port_profile` can express. The UI-only fields above (Port Mode Edge, Flow Control, PTP, …) are recorded as comments in `port_profiles.tf`. Resolved history:

1. ~~`unifi_devices` → live "UniFi Device" (singular), `dot1x_ctrl` `auto` vs `force_authorized`~~ — fixed in code 2026-09-08.
2. ~~`main` is really the live "Host Device"~~ — renamed, native → Main, `stp_port_mode` → true, 2026-09-08.
3. ~~`public_servers`, `private_servers`, `iot` do not exist live~~ — recreated by the user 2026-09-13 as **`Public Server`**, **`Private Server`**, **`IoT Device`** (singular names, `setting_preference = manual`, Port Mode Edge). Code aligned the same day; the resource addresses were kept (`public_servers`, `private_servers`, `iot`) so `device_*.tf` and `core/outputs.tf (removed 2026-09-14: the flat layout has no outputs)` did not need to change.

Still true: **nothing on any switch references the per-VLAN profiles yet.** Aggregation port 1 and Pro Max port 19 use inline native-VLAN overrides (§3.3, §3.4). Moving ports onto the profiles is the `TODO(port-overrides)` work, blocked on §14.3.

---

## 3. Devices, names, IPs and port overrides

### 3.1 Device identity

| MAC | Live name | Live mgmt IP | Code name (`device_*.tf`) | Diff |
|---|---|---|---|---|
| `28:70:4e:5c:b4:b2` | **UDM StKr** | WAN DHCP | UDM StKr | none (renamed in code before 2026-09-13) |
| `9c:05:d6:e2:6b:1d` | USW Pro Max 24 PoE | **static 192.168.99.2** (VLAN 99) | USW Pro Max 24 PoE | none since 2026-09-13 |
| `1c:6a:1b:98:38:ee` | USW Aggregation | **static 192.168.99.3** (VLAN 99) | USW Aggregation | none since 2026-09-13 |
| `9c:05:d6:d9:ad:79` | Living Room U7-Pro | **static 192.168.99.4** (VLAN 99) | Living Room U7-Pro | none since 2026-09-13 |
| `9c:05:d6:d9:af:65` | Bedroom U7-Pro | **static 192.168.99.5** (VLAN 99) | Bedroom U7-Pro | none since 2026-09-13 |

> **Management VLAN — 2026-09-13/14.** All four devices were re-homed from the untagged LAN to **UniFi Devices, VLAN 99** (runbook Phases 1–3) and on 2026-09-14 the trunks' native network followed (Phase 4): management is now untagged everywhere and Default DHCP is off. `mgmt_network_id` differs by device type on purpose — switches keep the override on, APs must have it off (stored as the Default LAN id) — see the runbook's Phase 4 table and the comments in `device_*.tf`.

> **`config_network` — corrected 2026-09-13.** All four devices declare the static addresses live reports, field for field (verified). Because the values match, the update `PUT` dropping the field is harmless: the read-back equals the plan and nothing is flagged. What §14.2 warns about is *changing* the address in code — that write never reaches the controller and fails post-apply. The 2026-09-08 `type = "dhcp"` block that *would* have failed is long gone. *Since provider 0.58.0 (upstream #482) the update sends `config_network` whenever it differs from live, so a change made in code now reaches the controller; it is still made in the UI first.*

Also:

- The controller itself is named **UDM StKr** (`super_identity.name`), hostname `UDM-StKr`. The checklist step is done; nothing in code manages it.
- ~~**LED override:** both APs report `led_override = "on"`~~ **Resolved 2026-09-08** — set to off live (browser log, change 5) and `led_override = "off"` is in both AP files. Original note: both APs reported LED forced **on**, not disabled. The checklist says "Disable LED on the Living Room and Bedroom APs". Either that step didn't take or it was reverted. Worth re-checking in the UI. The code has no `led_override` attribute at all either way. **This one is fixable today** — upstream #337 landed in v0.54.0, so `led_override = "off"` works on both APs (§14.8).
- ~~`device_u7_pro_living_room.tf` still carries `lifecycle { ignore_changes = [disabled] }` with a FIXME about the AP being offline/unadopted. It is adopted and online (`state = 1`) now, so that block can go.~~ Removed at provider 0.65.0 (§0.6 B5).
- All three `lifecycle { ignore_changes = [port_override] }` blocks (UDM, USW Aggregation, USW Pro Max) are still in place for the provider port-disable crash. As long as they stay, **none of the port drift in §3.2–§3.4 will ever be reconciled by an apply** — the code is documentation only. **Keep them** until v0.56.0: upstream #430 (merged, unreleased) shows a single declared `port_override` silently strips settings from *every* port on the device, which is very likely what flattened these switches in the first place (§14.3). *At provider 0.65.0 they still stay, for another reason: #430 shipped, but import and refresh never put `port_override` in state (§0.6 B1, §14.3).*

### 3.2 UDM StKr — ✅ aligned 2026-09-13

| Port | Live (= code) | Note |
|---|---|---|
| 1, 9 | *no override* | WAN2 / WAN1. Binding a WAN to a physical port is UniFi OS Internet configuration, not a `port_override` — the pre-reset code's `native_networkconf_id = var.wan_*` blocks never corresponded to anything stored. Removed, along with the `wan_primary_id`/`wan_secondary_id` plumbing into the `devices` module. `FIXME(unifi-ui-only)` in the file. |
| 2–8 | `Port N (Disabled)`, **disabled** | Port 2 was `Console` (Main access for the safety-net laptop) for the duration of runbook Phase 4 on 2026-09-14 and re-disabled the same day. It was originally disabled through the UI to learn the gateway's shape, 3–8 written as identical copies. The gateway stores a **smaller** disabled object than the switches: `forward "disabled"`, `port_security_enabled true` + `[]`, `tagged_vlan_mgmt "block_all"`, no native/voice network, `setting_preference "auto"`, `autoneg true`, `isolation/egress_rate_limit/port_keepalive false`, `sd_wan_underlay_port false` — no dot1x, STP or PoE keys at all. |
| 10 | `USW-Pro-Max-24-PoE`, UniFi Device profile | Uplink to the Pro Max (its port **26** since 2026-09-14); renamed from `SFP+ 1` on 2026-09-14 to match port 11's convention. The pre-reset code had the **Private Servers** profile here — wrong for an inter-switch trunk. |
| 11 | `USW-Aggregation`, UniFi Device profile | Renamed from `SFP+ 2`. |

Written via one `PUT /rest/device/<id>` (9 entries); read back, ports 10/11 unchanged except the rename, all four uplink/WAN ports still `up`, all four downstream devices still `state 1`.

#### Port assignments vs. the UI — what is *not* in tofu (2026-09-13 audit)

Profile assignments now match live on every port of every device. What the UI stores beyond that, per override shape:

| Shape | Provider-expressible — now declared explicitly | UI-only — `FIXME(unifi-ui-only)` in the file |
|---|---|---|
| Profiled port (all devices) | `name`, `poe_mode` (where present), `setting_preference`, `port_profile_id` — that *is* the whole stored object | none at this layer (the profile layer has its own FIXMEs in `port_profiles.tf`) |
| Disabled port, switches (Pro Max 9–11, Agg 2–7; Pro Max 25 since 2026-09-14) | `forward`, `port_security_enabled`, `tagged_vlan_mgmt`, `native_networkconf_id = null`, `voice_networkconf_id = null`, `setting_preference`, `poe_mode`, `autoneg`, `dot1x_ctrl`, `dot1x_idle_timeout`, `lldpmed_enabled`, `stp_port_mode`, `isolation`, `egress_rate_limit_kbps_enabled`, `port_keepalive_enabled`; `stp_edge_state "enabled"` since provider 0.65.0 | `stp_bpdu_guard_enabled true`, `stp_uplink false`, `eee_enabled false`, `link_debounce_auto true`, `multicast_router_mode "NONE"`, `sd_wan_underlay_port false` |
| Disabled port, gateway (UDM 2–8) | same minus dot1x/STP/PoE (the gateway doesn't store them) | `sd_wan_underlay_port false` |
| No override (UDM 1, 9; Pro Max 25 until 2026-09-14) | nothing to declare | UDM 1/9 are WAN-bound in UniFi OS; Pro Max 25 ran on switch defaults until it was disabled (§0.6 A4) |
| Agg port 1 specifically | profile assignment | BPDU Guard now comes from the Private Server profile (on) — UI-only |

Attribute names as at v0.55.0; v0.60.0 nests the prefixed ones (`port_security`, `dot1x`, `lldpmed`, `egress_rate_limit`). The stored `port_security_mac_address []` is not declared since #87: it reads back as null, and on the wire `[]` and an unset list are both left out (every `DevicePortOverrides` field is `omitempty`). `dot1x_idle_timeout 300` was never a provider default: the code declares it as `dot1x.idle_timeout = "5m0s"` since #87 (on 2026-09-13 it was left undeclared). `stp_edge_state` stays UI-only on the profiles (§2): only `port_override` gained it (upstream #695). Every write of a device's array carries the UI-only keys over from the controller's entry since v0.62.0 (upstream #652).

`FIXME(unifi-ui-only)` count: Pro Max 9, Aggregation 9, UDM 2, `port_profiles.tf` 9. At provider 0.65.0: Pro Max 6, Aggregation 7, UDM 2, `port_profiles.tf` 9 (§15).

### 3.3 USW Aggregation — ✅ aligned 2026-09-13

| Port | Live (= code) | Note |
|---|---|---|
| 1 | `Servacho-Gosho`, **Private Server profile**, pref auto | Was an inline native-VLAN override with ~20 explicit fields. Moved to the profile at the user's request. The inline override had BPDU Guard on and the profile initially did not; **BPDU Guard was enabled on the Private Server profile later the same day** (UI-only field, set via the API), so nothing was lost. Everything else was identical to the profile: native Private Servers, `force_authorized`, Port Mode Edge, tagged Allow All, STP on, LLDP-MED on, no isolation/storm control/rate limit. Servacho-Gosho verified still up at `192.168.5.10` afterwards. |
| 2–7 | `SFP+ N`, **disabled** | Same stored shape as Pro Max 9 (below). Previously no override at all (the code's `forward = "disabled"` blocks were phantoms). |
| 8 | `UDM-Pro-Max`, UniFi Device profile, pref auto | Renamed from `SFP+ 8`. |

Written via `PUT /rest/device/<id>` with the full `port_overrides` array (8 entries); read back and verified.

### 3.4 USW Pro Max 24 PoE — ✅ aligned 2026-09-13

Live, grouped (25 overrides on 2026-09-13, port 25 had none; 26 since 2026-09-14, when port 25 was disabled):

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
| 26 | UniFi Device, pref auto | `UDM-Pro-Max` (SFP+ 2) — the uplink to the UDM since 2026-09-14 |
| 25 | **disabled** since 2026-09-14 (§0.6 A4); *no override* before | `SFP+ 1 (Disabled)`; until 2026-09-14 the live uplink to the UDM |

Changed on the controller since, then mirrored (change log): ports 6, 12 and 18 renamed `LR-06`, `JetKVM-Servacho-Gosho` and `JetKVM-Michelangelo` (2026-09-14); port 21 carries Servacho-Gosho on the Private Server profile while its Aggregation uplink is out (2026-10-08, temporary); port 19 is on the Public Server profile for the Mac mini (2026-10-15). `device_usw_pro_max_24_poe.tf` holds all of it.

**What "disabled" actually is on the wire.** Port 9 was disabled through the UI (Port Profile toggle off → Port State: Disabled → Apply) and read back; ports 10, 11 and Aggregation 2–7 were then written as byte-identical copies. The stored override is a full manual one: `forward "disabled"`, `port_security_enabled true` + `port_security_mac_address []`, `tagged_vlan_mgmt "block_all"`, no `native_networkconf_id`, `setting_preference "manual"`, plus carried-over defaults (`dot1x_ctrl auto`, `stp_port_mode true`, `stp_edge_state enabled`, `stp_bpdu_guard_enabled true`, `lldpmed_enabled true`, `autoneg true`, `poe_mode auto`, `link_debounce_auto true`, `eee_enabled false`, `multicast_router_mode NONE`, `sd_wan_underlay_port false`, `isolation false`, `egress_rate_limit_kbps_enabled false`, `port_keepalive_enabled false`, `stp_uplink false`, `dot1x_idle_timeout 300`). The port table confirms `forward = disabled` on all three. This settles §14.3's point empirically: `forward = "disabled"` alone was never it.

Stored shape for profiled ports is `{name, poe_mode?, setting_preference, portconf_id}` — no `forward`, no `op_mode`. The code blocks now use exactly that. Ports 23/24/26 have no `poe_mode` key.

Live write: two `PUT /rest/device/<id>` calls with the full array; all overrides not being changed were diffed before/after and matched except for the intended renames.

> **Ports 6 and 18 — resolved 2026-09-13**, see the change log; port 12 likewise. The `Checklist vs. live discrepancy` note from 2026-09-08 (Host Device on 6/18, port 19 hand-rolled) is moot: 6 and 18 are on their profiles, and 19 is on Host Device like its neighbours.

---

## 4. WANs (`wans.tf`)

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

## 5. Wireless (`wlans.tf`)

All four SSIDs exist live with the right networks, bands, AP group and security type.

| SSID | Match | Diffs |
|---|---|---|
| `StKr` | ✅ | none — `wpaeap`, Main, RADIUS profile, WPA3 + transition, PMF optional |
| `StKr_Guest` | ✅ | none — `wpapsk`, Guest, `is_guest = true` |
| `StKr_IoT` | ⚠️ | code sets **`hide_ssid = true`**; live is **false** |
| `StKr_IoT_2.4GHz` | ⚠️ | code sets `wpa3_support = false`, `wpa3_transition = false`, `pmf_mode = "disabled"`; live is **true / true / optional** |

The `StKr_IoT_2.4GHz` diff matters: applying the code would drop WPA3 from that SSID. If it was created by cloning `StKr_IoT` in the UI, live is just the clone's inherited settings — decide which you actually want for the 2.4 GHz-only IoT gear.

~~**Keep the `ignore_changes = [passphrase, wlan_bands, wlan_band]` blocks.** All four SSIDs declare `"6g"`, and the fix for `6g` being dropped from the create response (#406) is merged but unreleased — see §14.4, which also notes that a third of that FIXME's rationale is now stale.~~ At provider 0.65.0 the four SSIDs ignore only `passphrase`: #406 shipped in v0.56.0 and the `wlan_band` default is gone since v0.59.0, so the plan now shows band drift. Bands still change in the UI first: the write derives `wlan_band` from `wlan_bands`, so a code-first switch between dual-band and 2.4 GHz-only fails after the PUT (`wlans.tf`).

---

## 6. RADIUS and 802.1X

### Live

- Site RADIUS setting: `enabled = true`, `configure_whole_network = true` (wired **and** wireless), shared secret set, auth 1812 / acct 1813, tunnelled reply on.
- `global_switch.dot1x_portctrl_enabled = true`; `dot1x_fallback_networkconf_id` was **empty** at this read. It is **Guest** since the remediation pass the same day (§0.5, change 1 of the 2026-09-08 session in [`unifi-browser-changes.md`](unifi-browser-changes.md)).
- RADIUS users: **`a.penchev`, `e.pencheva`, `vl.penchev`, `v.todorova`** — all four `tunnel_type 13`, `tunnel_medium_type 6`, `vlan 2`, `group_policy GLOBAL`. *(Updated 2026-09-13 — the last two were created by hand; at the original 2026-09-08 read only the first two existed.)*
- Default RADIUS profile with `vlan_enabled = true`, `use_usg_auth_server = true`.

### Differences

1. ~~**The site RADIUS setting is unmanaged.** `tofu/unifi/variables.tf` declares `radius_profile_secret` (and `tofu/unifi_module.tf` feeds it from Vault at `secret/unifi/radius/profile`), but **nothing consumes it** — there is no `unifi_setting_radius` resource anywhere. Dead variable, and the shared secret you set by hand is not in code.~~ Resolved in the 2026-09-08 remediation pass (§0.5): `unifi_setting.default` declares `radius = { secret = var.radius_profile_secret, … }` (`settings.tf`). The toggles that turn the server on, `enabled` and `configure_whole_network`, still have no attribute and stay set by hand (`settings.tf:57`, §15).
2. ~~**Global 802.1X port control is unmanaged.** It exists only inside the commented-out `unifi_setting_switch` block in `settings.tf`. That block also proposes `fallback_vlan_id = var.network_guest_id`; live has **no** fallback network configured. If you uncomment it later, that's a behaviour change, not a no-op.~~ At provider 0.65.0 it is managed: `unifi_setting.default` declares `global_switch.dot1x_portctrl_enabled = true` (`settings.tf`). The fallback VLAN (Guest) still has no attribute. It stays set by hand, under a `FIXME(unifi)`, and a `global_switch` write sends only the declared keys, so it leaves the fallback alone (§15).
3. **RADIUS users: ✅ in sync as of 2026-09-13.** Code declares four (`a.penchev`, `e.pencheva`, `vl.penchev`, `v.todorova`) and live now has the same four, each with exactly the attributes `unifi_radius_user` manages (`tunnel_type 13`, `tunnel_medium_type 6`, `vlan 2`). The one live-only field, `group_policy = "GLOBAL"`, is identical on the old and new pairs and is not exposed by the provider, so it is not drift. The Vault `radius_users` map carries all four keys (confirmed by the user 2026-09-13). One thing still stands between this and a clean apply:
   - `unifi_radius_user` has no `allow_existing`, so the four live accounts need a `tofu import` first (state still holds the pre-reset `_id`s) — otherwise the create `POST` is rejected for a duplicate name. This applies to every resource on the rebuilt controller, not just these. *(Done: the 2026-09-14 import put all 46 objects in state, §0.6 A1.)*

---

## 7. Firewall (`firewall.tf`)

### Live zones

| Zone | Networks |
|---|---|
| Internal | Default (Untagged), UniFi Devices (VLAN 99), Main, Private Servers, Qoax VPS, FMI{Codes} VPS |
| IoT *(custom zone, verified 2026-09-13; `unifi_firewall_zone.iot` since 2026-09-14)* | IoT |
| External | Vivacom Primary, Vivacom Secondary |
| Gateway | – |
| Vpn | – |
| **Hotspot** | **Guest** |
| **Dmz** | **Public Servers** |

Both checklist assignments (Hotspot ← Guest, DMZ ← Public Servers) are done, and the new firewall UI is active.

### Differences

1. **`Hotspot` ← `Guest` is not in code.** Only the DMZ zone is managed.
2. **Zone name casing.** Code uses `name = "DMZ"`; the controller reports `"Dmz"`. Likely harmless, but if the provider matches by exact name it will try to rename or fail to find it.
3. ~~**Zero custom firewall policies exist live.**~~ **Corrected 2026-09-14:** two custom policies exist — `Allow Main to IoT` (created 2026-09-08, index 10000) and `Allow Private Servers to IoT` (index 10001), both Internal → **IoT zone**, destination = the whole zone. `firewall.tf` mirrors both and declares the IoT zone. Policy **ordering cannot be managed** through the provider (§14, #348).
4. **Adding the Hotspot zone is load-bearing, not cosmetic.** On zone-based-firewall controllers a network only keeps `purpose = "guest"` while it belongs to the Hotspot zone; elsewhere the controller rewrites it to `corporate`. `unifi_network.guest` declares `purpose = "guest"` while nothing in code owns that zone (§14.9).

---

## 8. Port forwards (`port_forwards.tf`)

### Code and live since #85 (2026-11-02) — two rules

| Resource | Name | Proto | WAN | Forward |
|---|---|---|---|---|
| `unity_intercom` | **Unity Intercom** | udp | both WANs, 20101 | `unifi_client.mac4o_mini.fixed_ip` (**192.168.4.24**):20101 (`docs/unity-intercom.md`) |
| `os_tues_ssh` | **os-tues SSH** | tcp | both WANs, 22 | **192.168.4.31**:22 (`docs/os-tues.md`) |

Both were created by apply, at provider 0.55.0, when an undeclared `enabled` still defaulted to `true`. `nginx_proxy` (the `NGINX Server` below) became `soki web` on 2026-10-29, TCP 80 and 443 to soki at `192.168.10.41`, next to `soki_ssh` (TCP 2241 to soki's 22). #85 removed both when soki was torn down, so 80 and 443 are closed until the ingress VM (#83) gets its own forward.

**Adding a forward.** Since provider 0.62.0 a forward created from code without `enabled = true` is written disabled (upstream #553). Create it in the UI, read it back, mirror it and import it by `_id`. An existing rule keeps the controller's `enabled`, `logging` and `source_limiting.enabled` when they are undeclared, and since 0.65.0 a create without `protocol` is `tcp_udp` again.

### Live on 2026-09-13 — one rule

| Name | Proto | WAN | Forward |
|---|---|---|---|
| **NGINX Server** | tcp_udp | wan 80,443 | **192.168.5.58**:80,443 |

### Differences — ✅ resolved 2026-09-13

Re-read the same day: still exactly one live rule, unchanged. The user chose to keep what is live. `port_forwards.tf` now declares only `nginx_proxy`, renamed **`NGINX Server`** and pointed at **`192.168.5.58`** (resource address unchanged). Dropped from code: `fmicodes_db` (5432), `fmicodes_ssh` (2242), `fmicodes_ssh_worker` (2243) — the `.5.200/.201` nodes are still live clients, so this is a deliberate end to their public SSH/Postgres exposure — and the two `count = 0` placeholders `minecraft_server` and `fmicodes_intercom`. Live-only fields (`enabled`, `log`, `src_limiting_enabled`, `destination_ips`) are all defaults and have no provider attribute. *(Corrected 2026-11-02: they all have provider attributes, at v0.55.0 too — `enabled`, `logging`, `source_limiting`, `destination_ips` — left undeclared because live holds the defaults.)*

---

## 9. Fixed-IP clients (`clients.tf`)

### Live — four fixed IPs *(2026-09-08; seven as of 2026-09-13 — added `192.168.5.23` jetkvm-ce4ac3437e0d935d, `192.168.6.10` Living Room TV, `192.168.6.11` Bedroom TV)*

| Name | MAC | IP |
|---|---|---|
| `fmicodes-master-node` | `bc:24:11:c3:e5:f4` | 192.168.5.200 |
| `fmicodes-worker-node-1` | `bc:24:11:23:76:b5` | 192.168.5.201 |
| `hackjamhub-intercom` | `bc:24:11:8a:b7:98` | 192.168.5.215 |
| *(unnamed)* | `38:05:25:30:79:97` | 192.168.5.10 — this is Servacho-Gosho, last seen on USW Aggregation port 1, Private Servers |

> **Rewritten 2026-09-13.** `clients.tf` now declares exactly the eight live reservations (`.5.10`, `.5.20`, `.5.23`, `.5.200`, `.5.201`, `.5.215`, `.6.10`, `.6.11`) with only the attributes the controller has — `name` on the two TVs, `network_id` on the port-12 JetKVM, nothing else. Because every in-place `unifi_client` update fails at v0.55.0 (#428, §14.5), the file must stay attribute-exact: name or bind a client in the UI first, then mirror. Six of the eight are unnamed on the controller. *Since provider 0.56.0 in-place updates work (§14.5). The file still mirrors live attribute for attribute, now because the controller is the source of truth rather than because an update would fail, and `network_id` stays undeclared: it is the Network Override, not the reservation's network (at v0.55.0 too; since 0.62.0 the provider documents it so and reads it only while the override is on).*

### Differences

1. **All ten `unifi_client` resources in code are stale.** None of `MICHELANGELO`, `jetkvm`, `SAMI-DEV-MACHINE`, `rpi-petacho`, `networkboot-server`, `tsb-mint`, `DJAM-11`, `nixos`, `minecraft-fabric-server` or `Servacho-Gosho-JetKVM` exist on the rebuilt controller. This is the single biggest block of dead config.
2. **None of the four live fixed IPs are in code**, including `hackjamhub-intercom` (which isn't on the checklist either — undocumented manual step).
3. **MAC mismatch for Servacho-Gosho.** The checklist says "Set Servacho-Gosho IP to 192.168.5.10", and live has `38:05:25:30:79:97` → `.10`. Code's closest entries are `servacho_gosho_jetkvm` (`38:52:53:0a:09:87` → 192.168.5.20) and `jetkvm` (`30:52:53:08:45:16` → 192.168.5.21) — different MACs, different IPs. Note `192.168.5.10` is also the Proxmox endpoint hardcoded in `tofu/providers.tf`.
4. The live client is **unnamed** — you set the fixed IP but never gave it a name.
5. Live fixed IPs are plain `fixed_ip` on the client object with **no `network_id` binding**; code sets `network_id` on every client.

---

## 10. VPN (`vpn.tf`)

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
| `Vpn` zone: default policies only (Vpn → Internal/External/Gateway/Hotspot/Dmz allow, **Vpn → IoT block**, External → Vpn block) | `firewall.tf` declares nothing for the zone |
| `radius` setting enabled, `configure_whole_network`, `tunneled_reply`; one RADIUS profile (`use_usg_auth_server`) | OpenVPN block (commented) wants `data.unifi_radius_profile.default`, undeclared in `system` |

Observations:

- The WireGuard block is **code ahead of reality**, not drift: nothing was ever applied. The leading dot in `.StKr WireGuard Server` looks accidental. `192.168.8.1/24` collides with nothing (Teleport `.7`, management `.99`).
- The provider (v0.55.0) covers what is needed once a server exists: `unifi_vpn_server` (WireGuard/OpenVPN/L2TP, `dns`, `wan`) and **`unifi_wireguard_peer`** (`name`, `interface_ip`, `public_key`, `allowed_ips`) — peers can be code, their public keys are not secret.
- The controller refuses to create a WireGuard server without a private key (`api.err.WireguardMissingPrivateKey`; the provider generates one if unset). For code-follows-live, generate the key pair **outside** the controller (`wg genkey | tee private | wg pubkey`), put the private key in Vault first, paste it into the UI's Private Key field on creation — then `var.wireguard_private_key` and the controller agree and a later `tofu import` is clean.
- The OpenVPN block: FIXME unverified upstream (§14.6), references an undeclared data source, and Teleport + WireGuard already cover the remote-access need. Candidate for deletion.
- Firewall: a WireGuard network lands in the `Vpn` zone automatically, inheriting the defaults above. Vpn → IoT is blocked; Home Assistant is on Private Servers so that is not a problem, but reaching IoT devices directly over VPN would need a policy (`firewall.tf`).

Decisions needed: keep Teleport (yes, recommended — zero-config for phones, and it is the current lifeline); WireGuard server name / subnet / port; which peers; drop OpenVPN. Then: create live in the UI → read back → align `vpn.tf` → add `unifi_wireguard_peer` blocks.

---

## 11. Site settings (`settings.tf` and friends)

| Setting | Live | Code | Diff |
|---|---|---|---|
| Country | `100` (Bulgaria) | `100` | ✅ |
| NTP | `setting_preference = auto` | same | ✅ |
| IGMP snooping | `enabled = false` | `enabled = false` | ✅ |
| Auto speedtest | ✅ `enabled true`, `cron_expr "0 4 * * *"` — **set live 2026-09-13** (key was absent before) | same | ✅ |
| Updates schedule | `mgmt.auto_upgrade = true`, `auto_upgrade_hour = 3`, no weekday | ✅ `mgmt` block added 2026-09-13 (`auto_upgrade`, `auto_upgrade_hour`, `advanced_feature_enabled`, `debug_tools_enabled`, `unifi_idp_enabled`, `wifiman_enabled`) | weekday stays UniFi OS-only |
| **Console page** (Control Plane → Console, audited 2026-09-13) | Name `UDM StKr`; TZ Europe/Sofia; Screen on 80 %, idle 300 s, sync, touch; Night Mode 22:00–08:00; Email = UI Mail Server; Analytics Off; Support File Full; no certificates; Remote Access on; Direct Remote Connection off; SSH off | ✅ `lcm` block added (enabled, brightness, idle_timeout, sync, touch_event); country already managed | everything else 🚫 `FIXME(unifi)` in `settings.tf`: timezone, night mode, mail, analytics, support file, certificates, remote access, backup schedule are UniFi OS or `super_*` settings without a provider block; Direct Remote Connection and SSH map to `mgmt.direct_connect_enabled` and, unchecked, `mgmt.ssh.enabled`, and stay undeclared on purpose (§15) |
| **Admin accounts** | Owner + local admin `servacho-managment-plane` (is_super, site admin) | 🚫 no provider resource — documented as `FIXME(unifi)` in new `admins.tf` | UI-only |
| **Alarm Manager** (audited 2026-09-14) | 17 rules, all controller defaults from first boot, Notify → all admins, Always, push on / email off; no profiles, nothing custom | 🚫 UniFi OS alarm service (`/api/v2/alarms/…`), no provider resource — documented rule by rule as `FIXME(unifi)` in new `alarms.tf` | UI-only; defaults, so a reset reproduces them |
| Captive portal | `guest_access.portal_enabled = false` | not managed | **unmanaged** (checklist step done by hand) |
| mDNS | **`mode = "custom"`, `enabled_for = "some"`, Main + IoT, 19 services** (set 2026-09-13) | commented-out `unifi_setting_mdns` in `mdns.tf`, now with the verified identifier catalogue and wire format | **unmanaged** — **manual runbook item, live matches the documented intent**. No provider resource at v0.55.0; expressible as `unifi_setting.mdns` since 0.62.0 (§15) |
| Global switch | rstp, jumbo off, flowctrl off, DHCP snooping on, auto STP edge detection off, 802.1X on, RADIUS profile bound; 802.1X fallback VLAN Guest (since 2026-09-08, §6) | `unifi_setting.default.global_switch`: `stp_version = "rstp"`, `jumboframe_enabled = false`, `dhcp_snoop = true`, `dot1x_portctrl_enabled = true`; device isolation (`acl_device_isolation`) left undeclared, read from the controller | ✅ for the four declared keys (`unifi_setting.global_switch`, provider 0.58.0+). Flow control, auto STP edge detection, the RADIUS profile, L3 network isolation and the 802.1X fallback VLAN have no attribute and stay set by hand (`FIXME(unifi)` in `settings.tf`, §15); a `global_switch` write sends only the declared keys |
| Etherlighting | controller defaults (per-network auto colours; speed defaults `10M=#FFC105` etc.) | commented-out `unifi_setting_ether_lighting` with custom colours (FE `#ff0509`, GbE `#FFCC00`, 2.5GbE `#05ff19`, 10GbE `#054aff`, never applied) + a device-level block; removed, and `settings.tf` says why Etherlighting stays unmanaged | **unmanaged on purpose**: live runs the defaults. Expressible since 0.62.0 (`unifi_setting.etherlighting`, `unifi_device.etherlighting`) |
| WAN SLA | not checked | commented-out `unifi_wan_sla` | **unmanaged**; no provider resource at 0.65.0 either |

Notes:

- **Updates schedule.** The checklist says "Weekly at 4AM on Sunday". The Network app only reports `auto_upgrade_hour = 3` with no weekday, which means the weekly/Sunday/4 AM schedule is stored at the **UniFi OS** level, outside the Network application the provider talks to. Not expressible in this provider — document it as a manual step.
- **InnerSpace** is a UniFi OS application install. Same story: out of reach of `ubiquiti-community/unifi`, document as manual.
- ~~`usw_pro_max_24_poe.tf` sets `flowctrl_enabled = false` and `jumboframe_enabled = false` per-device; those are now site-global under `global_switch` and already match. Harmless but redundant.~~ Removed 2026-09-14 (§0.6 A6). Jumbo frames are managed site-wide as `global_switch.jumboframe_enabled`; flow control is site-wide too and set by hand.

---

## 12. Dead / broken plumbing in the code

**Mostly resolved by the 2026-09-14 flattening** (see `tofu/unifi/README.md`). The five submodules and their output → variable plumbing are gone; resources reference each other directly, so an unused input or output can no longer exist by construction.

1. ~~**`radius_profile_secret`** never referenced~~ — wired into `unifi_setting.default.radius` since 2026-09-08; now declared in `module.tf`.
2. ~~**`network_default_id`** passed but unused~~ — the whole output/variable layer was removed 2026-09-14.
3. ~~**`network_qoax_community_broadcast_vps_id`** output~~ — removed with the VLAN 11 network; no outputs remain.
4. ~~**`port_profile_public_servers_id` / `port_profile_iot_id`** each used once~~ — the profiles exist again (2026-09-13) and are referenced directly from `device_*.tf`.
5. **Three `ignore_changes = [port_override]` blocks — still real.** Until upstream PR #470 *and* the unreleased #430/#438 land, every port assignment in `device_*.tf` is decorative: it documents live, it does not reconcile it (§14.3).
   - The FIXME text itself is worth updating: it blames "a bug parsing the empty MAC allowlist required for the new UniFi OS Port State toggles", which is #470 and correct — but omits that `forward = "disabled"` was never the right mechanism, and that #430 (whole-array replacement stripping undeclared ports) is the more dangerous of the two.
   - *At provider 0.65.0:* still real, for another reason. #430/#438 and #470 shipped, but import and refresh never put `port_override` in state; the FIXME now says so (§0.6 B1, §15).
6. ~~**`vpn.tf`** OpenVPN block referenced an undeclared `data.unifi_radius_profile.default`~~ — the block was rewritten 2026-09-13 and the data source is declared once, in `module.tf` (it was declared three times before, once per submodule).
7. ~~Untracked working-tree changes~~ — committed 2026-09-13.
8. ~~`device_usw_pro_max_24_poe.tf` still sets `flowctrl_enabled = false` and `jumboframe_enabled = false` per device although both are site-global under `global_switch` and already match. Harmless, redundant.~~ Removed 2026-09-14 (§0.6 A6).

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

> **Status at provider 0.65.0 (re-checked 2026-11-02).** §14.2–§14.10 are the 2026-09-08 analysis against v0.55.0, kept as the record; each now opens with its status at 0.65.0. §14.1 is rewritten, and §14.11 and §14.12 carry a status column. Everything still not in code is listed in §15.

### 14.1 Version situation

- We pin `~> 0.65.0` in `tofu/providers.tf` and `tofu/unifi/module.tf`, and both `.terraform.lock.hcl` files lock 0.65.0 (released 2026-11-01) for all 13 platforms (#87). On 2026-09-08 the pin was `~> 0.55.0`, and every August fix sat unreleased on upstream `main`.
- The August fixes shipped in v0.56.0 on 2026-09-23 (upstream [#475](https://github.com/ubiquiti-community/terraform-provider-unifi/issues/475) closed). v0.60.0 nested the prefixed attributes (upstream [#478](https://github.com/ubiquiti-community/terraform-provider-unifi/pull/478)), so #87 migrated the configuration in the same commit as the pin.
- The first apply under 0.65.0, on #87's merge, upgrades the state in place, and 0.55.0 cannot read it afterwards. The copy taken before it is `/var/lib/opentofu/servacho-infrastructure.tfstate.pre-unifi-0.65.0` (serial 109) on the management plane. Going back to 0.55.0 means restoring that copy, which is valid only while no other apply has run since.
- 0.64.0 has the same state schema versions, so it reads the upgraded state (with a refresh, which CI always does). #87's configuration validates on 0.64.0 too, but `port_override.stp_edge_state`, declared since, exists only at 0.65.0: falling back means a re-pin, a re-lock and removing those lines.
- CI runs OpenTofu 1.11.8, which stores no resource identities. That keeps `unifi_device_port` out of reach (§14.3).

### 14.2 The root cause behind most of our FIXMEs

> **Status at 0.65.0: ✅ fixed.** Since v0.58.0 the update PUT carries every configurable device field: `config_network` (upstream #482), and `disabled`, the STP pair (now `stp = { version, priority }`), `lcm`, `poe_mode`, `flowctrl_enabled`, `jumboframe_enabled` and the rest (upstream #520, which closed #476); v0.62.0 added `etherlighting` (upstream #666). What remains is that every `unifi_device` update sends a PUT, even an empty one, which is why `forget_on_destroy` stays at its default (§15).

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

> **Status at 0.65.0: 🔧 the fixes shipped, the ignores stay.** #430, #438 and #427 shipped in v0.56.0, and #470 in v0.57.0 (for `unifi_port_profile` only). Since v0.62.0 a declared entry carries every key go-unifi models but the schema does not expose over from the controller's entry (upstream #652); a write of the array still drops keys go-unifi does not model and keys holding `[]` or `""`, such as the disabled ports' `port_security_mac_address []`. v0.65.0 exposes `port_override.stp_edge_state` (upstream #695). But import and refresh still never put `port_override` in state: lifting an ignore plans `+ port_override` for every block, and the apply writes the whole array unless every declared entry equals live, both ways. v0.65.0's `unifi_device_port` imports one port at a time, so the PR plan becomes an attribute-by-attribute check, but its Update sets no resource identity: under CI's OpenTofu 1.11.8 every in-place update fails after its PUT has reached the controller. Move to it once CI runs OpenTofu >= 1.12 or upstream sets the identity in its Update, one device per PR; until then the ignores stay. The #430 row below describes the v0.55.0 go-unifi pin, which did not model the UI-only keys.

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

### 14.4 `wlans.tf` — the `ignore_changes = [passphrase, wlan_bands, wlan_band]` FIXMEs

> **Status at 0.65.0: ✅ bands resolved, `passphrase` still ignored.** #406 shipped in v0.56.0 and the `wlan_band` default went in v0.59.0, so the SSIDs no longer ignore `wlan_bands`/`wlan_band`. The `passphrase` row below is wrong on two counts. The reporter closed #464 on 2026-09-17 as a validation mistake in their own module, with no provider change; but the symptom it describes was a real v0.55.0 Update defect, and it does apply to us: StKr (`wpaeap`, no passphrase declared) plans `passphrase -> null` whenever its imported state holds the controller's echo, and at v0.55.0 that apply failed on the sensitive value. v0.61.0 fixed it by keeping the planned passphrase in state instead of the echo (upstream #583). `passphrase_wo` already existed at v0.55.0. The ignore now stays only until a plan without it is clean, which proves OpenBao holds the live keys if the controller returns them in clear (unchecked; §15).

Three separate upstream problems sit behind that one workaround, and they have different statuses:

| Attribute | Status |
|---|---|
| `wlan_bands` with `"6g"` | [#406](https://github.com/ubiquiti-community/terraform-provider-unifi/pull/406) — **merged on `main`, unreleased.** Some controllers silently drop `6g` from the *create* response while accepting the same payload on update; the fix re-asserts with a follow-up update. All four of our SSIDs declare `["2g","5g","6g"]`, so at v0.55.0 a from-scratch create can still fail. **Keep this ignore.** |
| `passphrase` | [#464](https://github.com/ubiquiti-community/terraform-provider-unifi/issues/464) — **OPEN**, filed 2026-08-27 against 0.55.0: `.passphrase: inconsistent values for sensitive attribute` on open/guest WLANs. Doesn't hit us directly (all four SSIDs are `wpaeap`/`wpapsk`), but it's the same null-vs-empty confusion. `passphrase_wo` (write-only, #398) is merged-unreleased. **Keep this ignore.** |
| WLAN defaults | [#323](https://github.com/ubiquiti-community/terraform-provider-unifi/issues/323) — **fixed in v0.53.0.** `radius_profile_id`, `bc_filter_list` and the minimum-data-rate fields became `Optional + Computed`. The FIXME's "provider returns different structures" wording predates this; that half is stale. |

So the ignore blocks are still justified, but the comment should say *why* — it currently blames a vague structural mismatch rather than the specific `6g`-on-create asymmetry.

### 14.5 `clients.tf` — a fix we're missing

> **Status at 0.65.0: ✅ fixed in v0.56.0 (#447), with a new rule.** In-place `unifi_client` updates work, and `fixed_ip = ""` clears a reservation (#400, same release). A client diff that reaches main is therefore applied, no longer refused: name or bind clients in the UI first, then mirror. `network_id` is UniFi's Network Override, as it already was at v0.55.0; since v0.62.0 it reads only while the override is on (upstream #653). The fixed-IP binding of `jetkvm_servacho_gosho` and `mac4o_mini` lives in the client record's own `network_id`, which no attribute maps; declaring `network_id` on them would switch the override on (§15).

[#428](https://github.com/ubiquiti-community/terraform-provider-unifi/issues/428) — **merged as #447 on `main`, unreleased.** `last_ip` and `hostname` used `UseStateForUnknown`, which pins the planned value to prior state; the controller legitimately reports a different value between plan and apply (lease renewal, re-association), so **every in-place `unifi_client` update fails** with `Provider produced inconsistent result after apply: .last_ip`.

Resolution chosen 2026-09-13: **mirror live exactly** rather than delete. Creates work and a no-diff plan is a no-op, so an attribute-exact `clients.tf` is safe; only a *diff* triggers the failing update path. Also unreleased: clearing `fixed_ip` ([#400](https://github.com/ubiquiti-community/terraform-provider-unifi/pull/400)).

### 14.6 `vpn.tf` — the OpenVPN `CustomizeDiff` FIXME

> **Status at 0.65.0: 🔧 half fixed.** The `CustomizeDiff` FIXME went with the 2026-09-13 rewrite: the real cause was the `AES_256_GCM` cipher the controller rejects (§10, §14.12 #3). Since v0.64.0 `openvpn.mode` and `openvpn.encryption_cipher` default only on create, and an existing server keeps the controller's values (upstream #690), so `mode` is no longer declared. A create still sends `AES_256_GCM`, so `encryption_cipher = "AES_256_CBC"` stays pinned for a re-create; that default is to be reported upstream (§15).

I could not find an upstream issue or PR matching this. The two closed `unifi_vpn_server` issues ([#255](https://github.com/ubiquiti-community/terraform-provider-unifi/issues/255) private-key-required-on-create, [#256](https://github.com/ubiquiti-community/terraform-provider-unifi/issues/256) private key leaked in cleartext error messages) are both about WireGuard.

Two things follow: the OpenVPN behaviour is **unreported upstream**, and the FIXME's `CustomizeDiff` wording is suspect — that's SDKv2 vocabulary, and this provider is plugin-framework (`ModifyPlan`). Worth re-verifying before trusting the comment. If it reproduces, file it — this repo is clearly already a contributor there (#463 is ours), so it's the cheapest path to a fix.

~~Separately, and independent of any provider bug: the commented OpenVPN block referenced `data.unifi_radius_profile.default`, which its module never declared.~~ Resolved: the block is live code since 2026-09-13 and the data source is declared once in `module.tf` (2026-09-14).

### 14.7 The commented-out "provider doesn't support this yet" blocks

> **Status at 0.65.0: three of the four are expressible.** Etherlighting: #463 was closed for upstream #666 (v0.62.0, `unifi_setting.etherlighting` and `unifi_device.etherlighting`), and the colours stay unmanaged on purpose because live runs the defaults. mDNS: `unifi_setting.mdns` (v0.62.0, upstream #661). Global Switch: managed as `unifi_setting.global_switch` (v0.58.0) for STP mode, jumbo frames, DHCP snooping and 802.1X port control; the 802.1X fallback VLAN, the RADIUS profile, L3 network isolation, flow control and auto STP edge detection have no attribute and stay set by hand (§11). Per-device STP is in the update PUT since v0.58.0 (§14.2). Still nothing for the WAN SLA or the default security posture (§15).

| Block | Claim | Reality on 2026-09-08 |
|---|---|---|
| `settings.tf (ether lighting block)` + the `ether_lighting` block in `usw_pro_max_24_poe.tf` | "no native resource, PR #463" | ✅ Accurate. [#463](https://github.com/ubiquiti-community/terraform-provider-unifi/pull/463) still **OPEN** since 2026-08-31. |
| `mdns.tf` | "no `unifi_setting_mdns` for granular filtering" | ✅ Still accurate — nothing upstream addresses it. Live was brought to the documented Custom scope on 2026-09-13, so the block is now a faithful runbook rather than an aspiration. |
| `wans.tf (WAN SLA block)` | "no `unifi_wan_sla`, PR in progress: N/A" | ✅ Still accurate, still nothing upstream. |
| `settings.tf` — `unifi_setting_switch` / `unifi_setting_security` | "no native support for Global Switch Settings / Default Security Posture" | ✅ Accurate. Note [#476](https://github.com/ubiquiti-community/terraform-provider-unifi/issues/476) shows even per-device `stp_version`/`stp_priority` don't persist, so STP is unmanageable from either direction right now. |

All four are honest. Worth adding the check date to each so they can be re-audited without re-deriving.

### 14.8 FIXMEs that are now stale

> **Status at 0.65.0: all three acted on.** The LED override and `multicast_dns` were mirrored in September; the living-room AP's `ignore_changes = [disabled]` went at 0.65.0, since Read maps the missing key to `false`, the declared value (§0.6 B5).

1. **`device_u7_pro_living_room.tf`** — "the U7-Pro AP is currently physically offline or unadopted … remove this `ignore_changes` once it is plugged in". It **is** adopted and online (`state = 1`, static 192.168.1.4). *But* — `disabled` is one of the fields `buildMinimalUpdateDevice` drops (§14.2), so removing the ignore may just trade one error for another. Remove it and see, but don't be surprised.
2. **LED override is manageable now.** [#337](https://github.com/ubiquiti-community/terraform-provider-unifi/issues/337) (`unifi_device` LED updates fail with inconsistent result) was **fixed in v0.54.0** — `led_override*` is in the minimal PUT, and the update path re-asserts the planned values because the controller applies LED changes to APs asynchronously. So the §3.1 finding (both APs report `led_override = "on"` despite your checklist saying you disabled them) **is codifiable today**: add `led_override = "off"` to both AP resources.
3. **`unifi_network.multicast_dns`** — [#282](https://github.com/ubiquiti-community/terraform-provider-unifi/issues/282) fixed in v0.54.0: the corporate read path now preserves the configured value, falling back to the controller only when unset. Some UniFi OS gateways ignore per-network `mdns_enabled` entirely and always store `false`. Confirmed empirically on 2026-09-13: with the site-wide setting at `all` every network reported `true`; after scoping it to Main + IoT, exactly those two report `true`. The per-network flag is derived from the site-wide scope, so `networks.tf` should simply mirror it.

### 14.9 Things to know before touching the firewall (§7)

> **Status at 0.65.0:** ordering is still not manageable (`index` is computed only, and there is no reorder call). #473 shipped in v0.57.0, so `index` refreshes after an apply. #472 was fixed in v0.58.0 (`match_mac`, upstream #521; restricted to IP sources in v0.63.0) and #461 shipped in v0.57.0; neither live policy uses either. The Hotspot zone has been in code since 2026-09-08 (§0.5).

- **`unifi_firewall_policy.index` is read-only as of v0.54.0** ([#348](https://github.com/ubiquiti-community/terraform-provider-unifi/issues/348)). Ordering **cannot** be managed: `index` is a per-zone-pair controller-assigned ordinal, the integration API rejects it as input, the v2 endpoint ignores it and appends, and the UI's drag-to-reorder uses a private `batch-reorder` endpoint that 500s under API-key auth. Our `allow_main_to_iot` policy will land wherever the controller puts it. [#473](https://github.com/ubiquiti-community/terraform-provider-unifi/pull/473) (open) refreshes the assigned index on read.
- **Guest purpose is coupled to the zone** ([#276](https://github.com/ubiquiti-community/terraform-provider-unifi/issues/276), v0.54.0): on zone-based-firewall controllers a network only keeps `purpose = "guest"` while it belongs to the guest/Hotspot zone; placed elsewhere the controller rewrites it to `corporate`. Our `unifi_network.guest` declares `purpose = "guest"` but **nothing in code manages the Hotspot zone** (§7.1). That's not just a completeness gap — it's load-bearing for the network's purpose surviving an apply. Add the Hotspot zone resource.
- [#472](https://github.com/ubiquiti-community/terraform-provider-unifi/issues/472) (open): `match_mac` isn't exposed and updates silently reset it. [#461](https://github.com/ubiquiti-community/terraform-provider-unifi/pull/461) (open) adds the invert toggles.

### 14.10 Suggested sequencing

> **Status at 0.65.0:** superseded by §15. Of item 3, `config_network`, client updates and `wlan_bands` without the ignore are done; the `port_override` ignores stay for a different reason (§14.3). Of item 4, mDNS and per-device STP are expressible now, and the Global Switch Settings the provider covers are managed (§11). Item 5 narrowed to the cipher's create default, which is still to be reported, with three other reports (§15).

Given the above, the ordering that avoids wasted work:

1. ~~**Now, safe:** …~~ **All done by 2026-09-14** (see §0.6 for what remains). Original list: delete `clients.tf`; delete the `config_network = { type = "dhcp" }` block on the Pro Max (latent failure); fix the port profile names/attributes (§2 — `unifi_port_profile` is unaffected by the device-update bug); drop the VLAN 11 network + its output; fix the port-forward name/IP; add `led_override = "off"` to the APs; add the Hotspot zone; delete the dead `radius_profile_secret` and `network_default_id` plumbing.
2. **Now, but as documentation only:** correct the port_override blocks in `device_*.tf` to match live. They won't apply while `ignore_changes` is on, but they stop the files actively lying.
3. **Blocked on v0.56.0:** removing any `ignore_changes = [port_override]`; static mgmt IPs via `config_network`; re-adding `unifi_client` resources; `wlan_bands` without the ignore.
4. **Blocked indefinitely / manual runbook:** UniFi OS updates schedule, InnerSpace, mDNS granular filtering, WAN SLA, global switch settings, firewall policy ordering, per-device STP.
5. **Worth filing upstream:** the OpenVPN `unifi_vpn_server` behaviour (§14.6), if it still reproduces.

### 14.12 What the first real plan taught us — 2026-09-14

Runs 34835272924 → 34838813522 on `feat/unifi-port-config`, after the pre-reset state was cleared on the management plane. Everything below is either a provider gap (now a `FIXME(unifi)` in the file named) or a plan-output quirk worth knowing. **Concessions** are places where the code does *not* say what we mean because the provider cannot round-trip it.

| # | Finding | Kind | Where it is recorded | Status at 0.65.0 |
|---|---|---|---|---|
| 1 | `unifi_setting` **ImportState stores only the id**; the first plan shows every declared block as an add and `usg` as unknown. The first apply re-POSTs values that are already live. | provider gap | `settings.tf` FIXME | ✅ Fixed in v0.62.0 (upstream #668): the import reads every section except the secrets and the opt-in blocks, so a re-import plans one sensitive `radius.secret` update. |
| 2 | **`unifi_client` Read does not populate `network_id`** although the controller has it (JetKVM, Private Servers). Declaring it plans an in-place update on every run, and #428 makes that update fail. | provider gap → **concession**: `network_id` undeclared on the JetKVM reservation | `clients.tf` FIXME | 🔧 Not a Read bug: `network_id` has mapped to UniFi's Network Override (`virtual_network_override_id`) since v0.41.9, so at v0.55.0 too, where it read null because no override is set; v0.62.0 documents it so and reads it only while the override is on (upstream #653). The binding is the client record's own `network_id`, which no attribute maps. Updates work since v0.56.0. The concession is now a rule: never declare it (§15). |
| 3 | **`unifi_vpn_server` never reads `openvpn.mode` back** and **defaults `openvpn.encryption_cipher` to `AES_256_GCM`**, which the controller rejects on write. The controller stores neither field (verified live). `ignore_changes` on the two nested attributes was tried and **does not work** — the default is a provider plan modifier, injected after lifecycle rules (run 34841691079). | provider gap → **concession**: `encryption_cipher = "AES_256_CBC"` pinned (the controller's own default, so no wire change); `mode` will re-plan on every run until Read is fixed | `vpn.tf` FIXME | 🔧 Half fixed in v0.64.0 (upstream #690): an existing server keeps its stored mode and cipher, so `mode` is no longer declared. A create still sends `AES_256_GCM`, so the cipher stays pinned; to report (§15). |
| 4 | **`unifi_wan` reads `enabled = false`** because the controller stores no `enabled` on WAN objects; the provider defaults to `true`. | provider gap → **concession**: `enabled` in `ignore_changes` on both WANs, deliberately rather than "fixed", because a WAN update PUT is the one write that can take the internet down | `wans.tf` FIXME | ✅ Fixed: since v0.62.0 Read keeps a known `enabled` when the controller sends none (upstream #649), and v0.64.0 dropped the `true` default. The ignore is gone. |
| 5 | **`unifi_device.forget_on_destroy`** is provider-only yet Optional+Computed; import sets `true`, so the intended `false` plans an update PUT on all five devices (with the #463 hazard). | provider design → **concession**: left at the imported default | `device_*.tf` FIXME | Still true. The #463 hazard is gone (§14.2), but every device update sends a PUT, even an empty one (§15). |
| 6 | **A disabled DHCP server reads back as a null `dhcp_server` block**, so "DHCP off" cannot be declared; `enabled = false` planned a perpetual update. | provider quirk → **concession**: block absent on Default (Untagged) | `networks.tf` FIXME | Still true; since v0.62.0 an absent block sends nothing (§15). |
| 7 | **Device import lists no `port_override` at all** (0 blocks on the Pro Max, which has 25 live). Whether Read populates them is moot while `ignore_changes = [port_override]` is on, but a clean plan after #470/#430 also needs Read to return them. | observation, verify when the ignores go | §14.3 | Still true at 0.65.0: the reason the ignores stay (§14.3). |
| 8 | **Deleted objects make refresh fail** instead of dropping from state: `Error Reading network … not found` plus `Missing Resource Identity After Read` on every pre-reset entry. The only remedy is `tofu state rm` on the management plane. | provider bug (Read on 404) | `unifi-import-plan.md` step 2; worth an upstream issue | 🔧 Partly fixed in v0.60.0 (upstream #604): a deleted client, device, firewall zone or policy, port forward, port profile or RADIUS user drops from state and plans a re-create, which the next apply on main performs. `unifi_network`, `unifi_wan`, `unifi_wlan` and `unifi_vpn_server` still fail the refresh; to report (§15). |
| 9 | `hashicorp/vault` v5 deprecates the `vault_kv_secret_v2` data source (12 warnings per plan) in favour of the ephemeral resource. | dependency deprecation | `providers.tf` TODO(vault) | Open (§15). |
| 10 | Plan noise: any device update lists ~20 attributes as `(known after apply)` incl. `x_baresip_password (sensitive)`; `unifi_setting.usg` is unknown until the first apply. Neither is a diff. | quirk | here | Not re-checked at 0.65.0. |
| 11 | **`unifi_setting` apply aborts with "inconsistent result"**: `igmp_snooping.network_ids` is null in the plan and `[]` after the write. The POST itself succeeds. | provider bug (null vs empty list, same family as #470) → **concession**: `network_ids = []` declared | `settings.tf` FIXME | ✅ Fixed in v0.62.0 (upstream #668). `network_ids = []` stays declared so that a network ticked in the UI shows in the plan. |
| 12 | **`dhcp_guarding` cannot be written**: the update PUT carries `dhcpguard_enabled` but not the trusted servers (`dhcpd_ip_1..3`, which Read maps correctly), so the controller rejects it with `api.err.MissingIPAddress`. Any update to a guarded network fails. | provider bug → guarded networks are changed in the UI first, then mirrored | `networks.tf` FIXME | ✅ Fixed: since v0.56.0 go-unifi encodes `dhcpd_ip_1..3`, and since v0.62.0 an update sends `dhcpguard_enabled` only together with them (upstream #664). "Any update to a guarded network fails" overstated it: the only rejection seen came from turning guarding on for a network with no stored `dhcpd_ip_1`. |
| 13 | The OpenVPN update **wrote `openvpn_mode` and `openvpn_encryption_cipher` into the controller object** — keys the UI never creates. The controller accepted them and now stores them, so #3's perpetual `mode` diff may be gone. Watch the next plan. | side effect → confirmed gone: plan 34843770282 shows no `openvpn` diff | `vpn.tf` FIXME | History. Since v0.64.0 an undeclared `mode` keeps the stored value. |
| 14 | **`dhcp_guarding` Read is sticky**: `networkToModel` fills the block only on import (when guarding is live) or when the previous state already had it. UniFi Devices was imported with guarding OFF → null in state → after guarding was enabled live (API, 2026-09-14) the plan still adds the block on every run (34843770282, the last remaining diff). Adding the empty `dhcpd_ip_2/3` keys the UI stores changed nothing. | provider bug (Read preserves null) → fix: `state rm` + re-import that one network (import block kept for it) | `networks.tf` FIXME, A1 | Still true at 0.65.0 (§15). |

**Not concessions — genuine code corrections in `e40bdb1` / `30cf2ca`** (code said one thing, the controller another): Proxmox `node_name` of the management VM (would have destroyed it); `setting_preference = "manual"` on eight networks (Main is `auto`); DHCP guarding on seven networks (the plan would have switched it *off*); `group_rekey = 0` on all SSIDs and `no2ghz_oui = false` on the 2.4 GHz IoT SSID (real live values, verified against `/rest/wlanconf`).

**Intentional live changes the first apply will make**: UniFi Devices network gains `auto_scale`, `lte_lan`, `gateway_type = default` and DHCP guarding (normalising an API-created network to what the UI produces); `StKr_Guest` gets `is_guest = true` back (A8); site settings are re-POSTed (#1).

### 14.11 Watchlist

Re-checked against v0.65.0 on 2026-11-02: every upstream entry is closed. The reports still to file are the last rows, and §15 lists them with the rest of what is open.

| # | Type | Title | Status at 0.65.0 |
|---|---|---|---|
| [#463](https://github.com/ubiquiti-community/terraform-provider-unifi/pull/463) | PR | etherlighting + device update payload truncation *(ours)* | Closed unmerged on 2026-10-31 for #666 (v0.62.0: `unifi_device.etherlighting`, `unifi_setting.etherlighting`). The payload half shipped as #482 and #520 in v0.58.0. |
| [#470](https://github.com/ubiquiti-community/terraform-provider-unifi/pull/470) | PR | port_profile: keep an explicitly empty `port_security_mac_address` *(ours)* | Merged 2026-09-25, released in v0.57.0. `unifi_port_profile` only; `port_override` takes a separate path (§14.3). |
| [#473](https://github.com/ubiquiti-community/terraform-provider-unifi/pull/473) | PR | firewall-policy: refresh controller-assigned index | Merged, released in v0.57.0: `index` refreshes after an apply. Ordering is still not writable (#348). |
| [#477](https://github.com/ubiquiti-community/terraform-provider-unifi/pull/477) | PR | network: collapse duplicate DHCP NTP servers | Merged, released in v0.57.0. No network here sets DHCP NTP servers. |
| [#466](https://github.com/ubiquiti-community/terraform-provider-unifi/pull/466) | PR | site_to_site_vpn: tunnel IP + dynamic subnets in update PUT | Closed unmerged on 2026-10-31, covered by #660 (v0.62.0). The module has no `unifi_site_to_site_vpn`. |
| [#461](https://github.com/ubiquiti-community/terraform-provider-unifi/pull/461) | PR | firewall_policy: expose `match_opposite_*` | Merged 2026-09-29, released in v0.57.0. Neither live policy uses it. |
| [#478](https://github.com/ubiquiti-community/terraform-provider-unifi/pull/478) | PR | attribute nesting in objects | Released in v0.60.0, breaking; the configuration moved with #87. |
| [#476](https://github.com/ubiquiti-community/terraform-provider-unifi/issues/476) | issue | device: `stp_priority` dropped from update PUT | Closed 2026-10-02. The STP pair is in the update PUT since v0.58.0 (#520), as `stp = { version, priority }` since v0.60.0. |
| [#475](https://github.com/ubiquiti-community/terraform-provider-unifi/issues/475) | issue | request for a release with the August fixes | Closed 2026-09-23 with v0.56.0. |
| [#472](https://github.com/ubiquiti-community/terraform-provider-unifi/issues/472) | issue | firewall_policy: expose `match_mac` | Closed 2026-10-02: exposed in v0.58.0 (#521), restricted to IP sources in v0.63.0 (#676). Neither live policy matches MACs. |
| [#464](https://github.com/ubiquiti-community/terraform-provider-unifi/issues/464) | issue | wlan: null passphrase on open/guest wifi | Closed 2026-09-17 by its reporter (their own module's validation), no provider change. The symptom was a v0.55.0 Update defect, fixed in v0.61.0 (#583, §14.4). |
| — | to file (2026-09-14) | `unifi_client` Read drops `network_id` | Not a bug: `network_id` is the Network Override, as it already was at v0.55.0; v0.62.0 documents it so and reads it only while the override is on (#653). The reservation's own network has no attribute (§14.5). |
| — | to file (2026-09-14) | `unifi_vpn_server` never reads `openvpn.mode`, defaults a cipher the controller rejects | Half fixed in v0.64.0 (#690). The create default `AES_256_GCM` is **still to file** (§15). |
| — | to file (2026-09-14) | `unifi_wan` reads `enabled` the controller does not store | Fixed in v0.62.0 (#649); nothing to file. |
| — | to file (2026-09-14) | `unifi_setting` import populates nothing | Fixed in v0.62.0 (#668); nothing to file. |
| — | to file (2026-09-14) | Read on 404 errors instead of removing from state | Fixed for seven of our types in v0.60.0 (#604); **still to file** for `unifi_network`, `unifi_wan`, `unifi_wlan` and `unifi_vpn_server` (§15). |
| — | to file (since v0.58.0) | `unifi_port_profile` writes send eight unmodelled booleans as `false` | **To file** (§15). |
| — | to file (since v0.65.0) | `unifi_device_port` Update sets no resource identity | **To file** (§15). |

---

## 15. What is still not in code at provider 0.65.0

Every `FIXME` and `TODO` marker in `tofu/` on 2026-11-02, one row each, from `git grep -n -E 'FIXME|TODO' -- tofu`: 60 markers. Line numbers are those of that tree, so re-run the grep after editing a file. Paths are under `tofu/unifi/` except `tofu/providers.tf`. The grep also matches four lines that are not markers: `tofu/unifi/README.md:38` and `:40` define the two `FIXME` kinds, and `vpn.tf:2` and `vpn.tf:18` point at markers below them.

Why a marker stays:

- **Blocked upstream:** the provider cannot express or safely write it at 0.65.0.
- **Deliberately unmanaged:** expressible, but declaring it costs a controller write we choose not to make.
- **UI-only by design:** outside the provider's reach or scope; the comment is the rebuild runbook.
- **Needs a live read first:** expressible, but the code must mirror a value nobody has read yet.

One row is **planned** in this stack: mDNS (`mdns.tf:4`). The Global Switch Settings the provider covers are managed (§11); `settings.tf:71` lists the rest.

| Where | What | Why it stays | What would unblock it |
|---|---|---|---|
| `tofu/providers.tf:41` | `TODO(vault)`: the `vault_kv_secret_v2` data sources are deprecated by hashicorp/vault v5 in favour of the ephemeral resource | **Blocked upstream** in part (`unifi_radius_user.password` has no write-only twin), and **needs a live read first** for the WireGuard key | The ephemeral migration, below |
| `admins.tf:3` | The two admin accounts: the owner and the tofu service account | **UI-only by design:** UniFi OS users, no admin resource; the service account must exist before any plan | An admin resource upstream; import the service account first |
| `alarms.tf:3` | The 17 Alarm Manager rules, all controller defaults | **UI-only by design:** UniFi OS alarm service, outside the Network API; a reset reproduces the defaults | An alarm resource upstream. A custom alarm is listed in the file meanwhile |
| `clients.tf:44` | `jetkvm_servacho_gosho` is bound to Private Servers | **Blocked upstream:** the binding is the client record's own `network_id`, which no attribute maps; the resource's `network_id` is the Network Override and must not be declared | An attribute for the reservation's network (a feature request upstream). A rebuilt reservation is re-bound by hand (`PUT /rest/user`) |
| `clients.tf:103` | `mac4o_mini` is bound to Public Servers | **Blocked upstream**, as `clients.tf:44` | As `clients.tf:44` |
| `device_u7_pro_bedroom.tf:4` | `forget_on_destroy` stays at its default `true`; the intent is `false` | **Deliberately unmanaged:** declaring it plans an update, and every `unifi_device` update sends a PUT, even an empty one | An upstream Update that skips an empty device PUT, or one deliberate PUT per device in a quiet window after a live read of it |
| `device_u7_pro_living_room.tf:4` | `forget_on_destroy`, as the bedroom AP | **Deliberately unmanaged** | As `device_u7_pro_bedroom.tf:4` |
| `device_udm_pro_max.tf:4` | `forget_on_destroy`, as the bedroom AP | **Deliberately unmanaged** | As `device_u7_pro_bedroom.tf:4` |
| `device_udm_pro_max.tf:9` | `ignore_changes = [port_override]`: the port blocks document live, apply does not reconcile them | **Blocked upstream:** import and refresh never put `port_override` in state, and `unifi_device_port` fails every in-place update on OpenTofu 1.11 (§14.3) | CI on OpenTofu >= 1.12, or upstream setting the identity in `unifi_device_port`'s Update; then one PR per device that imports its ports as `unifi_device_port`, below |
| `device_udm_pro_max.tf:22` | The WAN-to-port binding of ports 1 (WAN2) and 9 (WAN1) | **Blocked upstream:** the binding sits outside `port_overrides`, probably in the device's `ethernet_overrides` (unchecked on this UDM), which the provider neither exposes nor sends | A live read of which key holds the binding, then the provider exposing it |
| `device_udm_pro_max.tf:29` | `sd_wan_underlay_port = false` on ports 2-8 | **Blocked upstream:** no attribute; every write of the array carries it over from the controller (since v0.62.0) | The attribute on `port_override` and `unifi_device_port` |
| `device_usw_aggregation.tf:4` | `forget_on_destroy`, as the bedroom AP | **Deliberately unmanaged** | As `device_u7_pro_bedroom.tf:4` |
| `device_usw_aggregation.tf:26` | `ignore_changes = [port_override]` | **Blocked upstream**, as `device_udm_pro_max.tf:9` | As `device_udm_pro_max.tf:9` |
| `device_usw_aggregation.tf:40` | BPDU Guard on port 1 (Servacho-Gosho), from the Private Server profile | **Blocked upstream:** no attribute on either layer, and any profile write turns it off (`port_profiles.tf:19`) | `stp_bpdu_guard_enabled` on `unifi_port_profile`, and profile writes that keep what they do not model |
| `device_usw_aggregation.tf:53` | `stp_bpdu_guard_enabled = true` on disabled ports 2-7 | **Blocked upstream:** no `port_override` attribute; every write of the array carries it over from the controller | The attribute on `port_override` and `unifi_device_port` |
| `device_usw_aggregation.tf:54` | `stp_uplink = false` on ports 2-7 | **Blocked upstream**, as `:53` | As `:53` |
| `device_usw_aggregation.tf:55` | `eee_enabled = false` on ports 2-7 | **Blocked upstream**, as `:53` | As `:53` |
| `device_usw_aggregation.tf:56` | `link_debounce_auto = true` on ports 2-7 | **Blocked upstream**, as `:53` | As `:53` |
| `device_usw_aggregation.tf:57` | `multicast_router_mode = "NONE"` on ports 2-7 | **Blocked upstream**, as `:53` | As `:53` |
| `device_usw_aggregation.tf:58` | `sd_wan_underlay_port = false` on ports 2-7 | **Blocked upstream**, as `:53` | As `:53` |
| `device_usw_pro_max_24_poe.tf:4` | `forget_on_destroy`, as the bedroom AP | **Deliberately unmanaged** | As `device_u7_pro_bedroom.tf:4` |
| `device_usw_pro_max_24_poe.tf:25` | `ignore_changes = [port_override]` | **Blocked upstream**, as `device_udm_pro_max.tf:9` | As `device_udm_pro_max.tf:9` |
| `device_usw_pro_max_24_poe.tf:106` | `stp_bpdu_guard_enabled = true` on disabled ports 9-11 and 25 | **Blocked upstream**, as `device_usw_aggregation.tf:53` | As `device_usw_aggregation.tf:53` |
| `device_usw_pro_max_24_poe.tf:107` | `stp_uplink = false` on ports 9-11 and 25 | **Blocked upstream**, as `device_usw_aggregation.tf:53` | As `device_usw_aggregation.tf:53` |
| `device_usw_pro_max_24_poe.tf:108` | `eee_enabled = false` on ports 9-11 and 25 | **Blocked upstream**, as `device_usw_aggregation.tf:53` | As `device_usw_aggregation.tf:53` |
| `device_usw_pro_max_24_poe.tf:109` | `link_debounce_auto = true` on ports 9-11 and 25 | **Blocked upstream**, as `device_usw_aggregation.tf:53` | As `device_usw_aggregation.tf:53` |
| `device_usw_pro_max_24_poe.tf:110` | `multicast_router_mode = "NONE"` on ports 9-11 and 25 | **Blocked upstream**, as `device_usw_aggregation.tf:53` | As `device_usw_aggregation.tf:53` |
| `device_usw_pro_max_24_poe.tf:111` | `sd_wan_underlay_port = false` on ports 9-11 and 25 | **Blocked upstream**, as `device_usw_aggregation.tf:53` | As `device_usw_aggregation.tf:53` |
| `firewall.tf:37` | Policy order: 10000 and 10001 in the Internal → IoT pair | **Blocked upstream:** `index` is computed only, and there is no reorder call (upstream #348) | A reorder call upstream |
| `mdns.tf:4` | The Gateway mDNS Proxy: Custom, Main + IoT, 19 services, applied by hand. The comment still says v0.55.0 | **Needs a live read first:** expressible as `unifi_setting.mdns` since v0.62.0, which an import does not read | **Planned:** `unifi_setting.mdns` in the PR after the Global Switch one, after reading the stored service order |
| `networks.tf:11` | `dhcp_guarding` Read is sticky: a network imported unguarded never reads its guarding back | **Blocked upstream:** Read fills the block only on an import with guarding on, or when state already has it | A Read that fills it whenever guarding is on. Meanwhile a `state rm` and re-import adopt the block with no write (`unifi-import-plan.md`); an apply would rewrite the four guard keys instead |
| `networks.tf:29` | Default (Untagged) has DHCP off, and `dhcp_server` is not declared | **Deliberately unmanaged:** Read fills `dhcp_server` only on an import with DHCP on, so declaring `enabled = false` costs one write of every `dhcp_server` key but `boot` | A Read that fills `dhcp_server` while DHCP is off, or accepting that one write |
| `port_profiles.tf:6` | Port Mode (`stp_edge_state`): Infrastructure on UniFi Device, Edge on the other four | **Blocked upstream:** no `unifi_port_profile` attribute; upstream #695 added it to `port_override` only | The attribute on `unifi_port_profile` |
| `port_profiles.tf:8` | Flow Control on, all five | **Blocked upstream:** no attribute, and every profile write sends it as `false` (`:19`) | The attribute on `unifi_port_profile`, and `:19` fixed |
| `port_profiles.tf:9` | PTP on, all five | **Blocked upstream**, as `:8` | As `:8` |
| `port_profiles.tf:10` | QoS profile: custom, no policies (UI: Off) | **Blocked upstream:** no attribute; never sent | The attribute on `unifi_port_profile` |
| `port_profiles.tf:11` | STP Uplink off, all five | **Blocked upstream:** no attribute; a profile write sends `false`, which is the live value | As `:8` |
| `port_profiles.tf:12` | BPDU Guard: on for Host Device, Private Server and IoT Device | **Blocked upstream**, as `:8`; a profile write turns it off | As `:8` |
| `port_profiles.tf:15` | Link Debounce: Auto, 300 ms | **Blocked upstream**, as `:8` (the time itself is never sent) | As `:8` |
| `port_profiles.tf:16` | Energy Efficient Ethernet off | **Blocked upstream:** no attribute; a profile write sends `false`, which is the live value | As `:8` |
| `port_profiles.tf:17` | Multicast Router Port: `NONE` | **Blocked upstream:** no attribute; never sent | The attribute on `unifi_port_profile` |
| `port_profiles.tf:19` | Every profile write resets eight unmodelled booleans to `false`; never apply a plan that updates a profile | **Blocked upstream:** create and update send a profile built from the schema alone | Upstream writing a profile over the stored one, as #652 did for `port_override`; to report, below |
| `port_profiles.tf:54` | The 802.1X fallback VLAN is Guest, set by hand | **Blocked upstream:** not in `unifi_setting.global_switch`; a `global_switch` write leaves it alone | `dot1x_fallback_networkconf_id` on `global_switch` upstream |
| `radius.tf:3` | `unifi_radius_user` has no `allow_existing` | **Blocked upstream:** a user made by hand is imported before it is declared, or the create fails on the duplicate name | `allow_existing` upstream |
| `settings.tf:57` | The site RADIUS server's `enabled` and `configure_whole_network`, on by hand | **Blocked upstream:** go-unifi models both, the provider does not; a `radius` write never sends them | The two attributes on `unifi_setting.radius` |
| `settings.tf:71` | The Global Switch Settings with no attribute, set by hand: 802.1X fallback VLAN Guest, the RADIUS profile 802.1X uses (one is bound), L3 network isolation off, flow control off, auto STP edge detection off | **Blocked upstream:** go-unifi models all five keys, `unifi_setting.global_switch` does not; its write sends only the declared keys and leaves these alone | `dot1x_fallback_networkconf_id`, `radiusprofile_id`, `acl_l3_isolation`, `flowctrl_enabled` and `auto_stp_edge_detection_enabled` on `global_switch` upstream. The fallback VLAN is load-bearing (`port_profiles.tf:54`) |
| `settings.tf:87` | Console name "UDM StKr" | **Blocked upstream:** `unifi_setting` has no block for the console's `super_*` settings | A block for them upstream |
| `settings.tf:89` | Time zone Europe/Sofia (`locale`) | **Blocked upstream:** no `locale` block | A `locale` block upstream |
| `settings.tf:91` | Night Mode 22:00-08:00 | **Needs a live read first:** `unifi_device.lcm.night_mode` carries it only if the UDM's device record holds the console's schedule (unchecked) | A read of the UDM's `stat/device` record |
| `settings.tf:94` | Email Services: UI Mail Server (`super_mail`) | **Blocked upstream:** no `super_mail` block | A `super_mail` block upstream |
| `settings.tf:95` | Analytics & Improvements off (`super_mgmt`) | **Blocked upstream:** no `super_mgmt` block | A `super_mgmt` block upstream |
| `settings.tf:96` | Support File Full, Certificates none, Remote Access on, Direct Remote Connection and SSH off | **UI-only by design:** Support File and Certificates are UniFi OS console settings. **Blocked upstream:** Remote Access is `super_cloudaccess.enabled`, and there is no `super_cloudaccess` block. **Deliberately unmanaged:** Direct Remote Connection and SSH map to `mgmt.direct_connect_enabled` and, unchecked, `mgmt.ssh.enabled`; both are absent from the record and stay undeclared | A `super_cloudaccess` block upstream; nothing in the Network API for Support File and Certificates |
| `settings.tf:100` | Updates: weekly, Sunday 4 AM; only the hour reaches the Network app | **UI-only by design:** weekday and channels are UniFi OS; `mgmt.auto_upgrade.hour` is managed | Nothing in the Network API |
| `settings.tf:102` | Backups: monthly auto backup (`super_mgmt.autobackup_cron_expr`) | **Blocked upstream:** no `super_mgmt` block | A `super_mgmt` block upstream |
| `settings.tf:105` | Default security posture Allow All (`global_network.default_security_posture = "ALLOW_ALL"`) | **Blocked upstream:** no attribute, no resource and no go-unifi type | A `global_network` setting in go-unifi and the provider |
| `vpn.tf:8` | Teleport (enabled, `192.168.7.1/24`) and Site Magic (on, no tunnels) | **UI-only by design:** the `unifi_teleport` data source (v0.62.0) only reads it; upstream #589, the request behind that data source, left managing Teleport out of its scope; nothing covers Site Magic | Nothing planned upstream |
| `vpn.tf:37` | `encryption_cipher = "AES_256_CBC"` pinned, a concession for a re-create | **Blocked upstream:** a create still defaults to `AES_256_GCM`, which the controller rejects | A create default the controller accepts; to report, below. The pin changes nothing on the wire meanwhile |
| `vpn.tf:44` | OpenVPN values without an attribute: protocol, MSS clamp, MTU, compression, DHCP range; `setting_preference` always sent as `manual` | **Blocked upstream:** no attributes; updates never send the first five, and every create and update sends `setting_preference = "manual"` | The attributes on `unifi_vpn_server` |
| `wans.tf:36` | The intended WAN SLA monitor (live has none) | **Blocked upstream:** no WAN SLA resource | A WAN SLA resource upstream |
| `wlans.tf:1` | `passphrase` stays in `ignore_changes` on all four SSIDs | **Needs a live read first:** whether the controller returns `x_passphrase` to the tofu account in clear or masked is unchecked. If in clear, a plan without the ignore that comes back clean proves OpenBao holds the live keys (both IoT SSIDs read one variable, so their live keys must match) | A PR that drops the ignore and shows a clean plan; StKr may show a one-time `passphrase -> null`, which sends nothing. A `~ passphrase` on a PSK SSID means OpenBao differs from live: fix OpenBao, never apply it. A diff that never clears means a masked key: move to `passphrase_wo` instead |

### 15.1 Follow-ups that are not `FIXME` markers

- **The `TODO(vault)` ephemeral migration** (`tofu/providers.tf:41`). Read the provider credentials through the ephemeral `vault_kv_secret_v2` (provider blocks take ephemeral values on OpenTofu 1.11), and move four of the module's five secrets to the provider's write-only twins: `passphrase_wo` with `passphrase_wo_version` for the two WLAN passphrases, `radius_secret_wo` for the site RADIUS secret, and `wireguard.private_key_wo` for the WireGuard key. Limits: `unifi_radius_user.password` has no twin, so `radius_users` stays a data source; `radius_secret_wo` leaves `radius.secret` in `unifi_setting`'s state until a `state rm` and re-import; a WireGuard update without the key sends a freshly generated one unless the controller returns `x_wireguard_private_key` to the tofu account, so read that first; and a write-only passphrase is no longer compared with live, so a key changed in the UI stops showing in the plan. `tofu/root_plane.tf` holds one more `vault_kv_secret_v2` (`management_plane_ssh`), which the TODO does not mention; the 14 deprecation warnings per plan count it.
- **`unifi_device_port` once CI runs OpenTofu >= 1.12** (or once upstream sets the identity in its Update, report 1 below). It is the way out of the three `port_override` ignores (§14.3): one PR per device, every port that has an override entry imported by `<device_mac>/<index>` (UDM ports 1 and 9 have none; their import fails with "Port Has No Overrides"), merged only on a plan of imports alone. Before the first write after that, read back a disabled port: every `unifi_device_port` write PUTs the device's whole array, which drops the empty `port_security_mac_address []` the disabled ports store, and whether the controller still shows them as Port State Disabled is unchecked. Moving CI is safe at 0.65.0: since v0.62.0 the provider fills in the identities that state written by OpenTofu 1.11 lacks (upstream #647). Pro Max port 21 and Aggregation port 1 change again when Servacho-Gosho moves back to its DAC: import them after that, or plan a `state rm` and re-import.
- **A feature request for the client binding.** Ask upstream to expose the reservation's own network (the user record's `network_id`, set with the fixed IP) apart from `network_id`, which is the Network Override (upstream #653), so `clients.tf:44` and `:103` can be declared and a rebuilt reservation is re-bound by apply. Not filed yet.
- **Upstream reports to file.** None is filed yet.
  1. `unifi_device_port`: Update sets no resource identity, so under OpenTofu < 1.12 every in-place update fails with "Missing Resource Identity After Update" after its PUT. Create already sets it; Update needs the same call.
  2. `unifi_port_profile`: create and update send a profile built from the schema alone, so eight booleans the provider does not model go out as `false`: BPDU Guard, flow control, PTP, link debounce auto, EEE, STP uplink, stable port and `ld_status`.
  3. `unifi_vpn_server`: a create defaults `openvpn.encryption_cipher` to `AES_256_GCM`, which the controller rejects (it accepts `AES_256_CBC` or `BF_CBC`, as go-unifi's own field definition says).
  4. Read on 404 for `unifi_network`, `unifi_wan`, `unifi_wlan` and `unifi_vpn_server`: a deleted object fails the refresh instead of leaving state, as the other resources do since v0.60.0 (upstream #604). The remedy until then is `tofu state rm` on the management plane.
- **Issue #83, the shared ingress VM (draft PR #88).** 80 and 443 stay closed until it exists. Its forward is made in the UI and imported, not created from code (§8).
