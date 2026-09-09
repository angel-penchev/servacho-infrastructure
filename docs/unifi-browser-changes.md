# UniFi controller — changes made through the browser

Every change made to the live controller (`https://192.168.1.1`, site `default`) outside of OpenTofu is logged here, newest session first. Anything in this file is **drift by construction**: it exists on the controller and is either not expressible in the pinned provider, or is waiting for a `tofu apply` from the management plane.

Changes were made through the user's authenticated Chrome session against the controller's own REST API (`/proxy/network/api/s/default/...` and `/proxy/network/v2/api/site/default/...`) — the same endpoints the UniFi web UI uses. Each write was a read-modify-write of the full object, followed by a read-back to verify.

---

## Pending — authorised 2026-09-09, NOT yet applied

**Nothing in this section has been written to the controller.** Unlike every other section in this file, this is a forward-looking checklist: the admin-panel half of the "Guest can reach the two TVs" change. The OpenTofu half is already committed (`security/firewall.tf`, `core/port_profiles.tf`, `devices/usw_pro_max_24_poe.tf`, `system/mdns.tf`). Convert this into a normal change record — endpoints, before/after values, read-back — once the steps are carried out.

Order matters: **step 1 before step 4**, or the DHCP reservation binds a MAC the TV will discard.

### Devices in scope

| Device | MAC | Currently | Target |
|---|---|---|---|
| `SDMC Android TV Box DV8919` — the EON box, **living room** | `b0:b3:69:41:2c:9b` | Guest VLAN 3, `192.168.3.69`, wired Pro Max port 6 | IoT VLAN 6, `192.168.6.10`, named `Living Room TV` |
| `Sony BRAVIA SmartTV` — **bedroom** | `52:4b:e7:7b:a6:c7` ⚠️ randomized | IoT VLAN 6, `192.168.6.93`, Wi-Fi `StKr_IoT` | IoT VLAN 6, `192.168.6.11`, named `Bedroom TV` |
| `jetkvm-ce4ac3437e0d935d` | `30:52:53:0d:1a:68` | Guest VLAN 3, **no IP at all**, wired Pro Max port 18 | Private Servers VLAN 5, `192.168.5.23` |

⚠️ The BRAVIA's MAC has the locally-administered bit set (`52:`) — it is a per-SSID random MAC the TV may rotate, which would break both a DHCP reservation and any MAC-based rule. Turn randomization off on the TV (Android TV → Settings → Network & Internet → `StKr_IoT` → Privacy → *Use device MAC*) and re-read the real MAC before reserving. Everything downstream matches on **IP**, not MAC, so a later rotation can only break the reservation, never the policy.

Note the BRAVIA is in the **bedroom**, not the living room, which is why it associates to the Bedroom U7-Pro (`9c:05:d6:d9:af:65`). Only the EON box is a living-room device.

### Steps

| # | Where | What | Codifiable? |
|---|---|---|---|
| 1 | On the TV itself | Turn off MAC randomization on the BRAVIA, re-read its MAC in Client Devices | n/a — device-side |
| 2 | Settings → Profiles → Port → Create New | Create `Public Server` (native VLAN 4), `Private Server` (VLAN 5), `IoT Device` (VLAN 6), **in that order**. Mirror the live profiles: `forward = customize`, `poe_mode = auto`, autoneg, `dot1x_ctrl = force_authorized`, `tagged_vlan_mgmt = auto`, Port Mode not Edge | Yes — `core/port_profiles.tf`, already renamed to the singular form |
| 3 | UniFi Devices → USW Pro Max 24 PoE → Ports | Port 6 (`LR-06`) → `IoT Device`; port 18 (`BR-02`) → `Private Server` | Only nominally — `devices/usw_pro_max_24_poe.tf` records intent but `ignore_changes = [port_override]` means no apply pushes it (#430 / #438) |
| 4 | Client Devices → client → Settings → Fixed IP | The three reservations in the table above, plus names for the two TVs | **No.** Every in-place `unifi_client` update fails at v0.55.0 (`inconsistent result after apply: .last_ip`, #428/#447, unreleased) — see §14.5 |
| 5 | Settings → Security → Policy Engine → Zones | Create zone `IoT` containing the IoT network. It leaves `Internal` automatically | Yes — `unifi_firewall_zone.iot`, but needs `tofu import` afterwards (a custom zone cannot be imported by name) |
| 6 | Settings → Profiles → Network Lists | Create address group `TV Media Endpoints` = `192.168.6.10`, `192.168.6.11` | Yes — `unifi_firewall_group.tv_media_endpoints` |
| 7 | Settings → Security → Policy Engine | The four policies below | Yes — all four in `security/firewall.tf` |
| 8 | Settings → Networks → Global Network Settings | **Leave `Gateway mDNS Proxy` alone** (already `mode: all` / `enabled_for: all`) | **No** — see `system/mdns.tf`; needs an upstream PR in *both* go-unifi and the provider |

### The four policies (step 7)

| Name | Action | Source | Destination | Notes |
|---|---|---|---|---|
| `Block IoT Initiated` | BLOCK | zone `IoT`, Any | zone `Internal`, Any | Connection State → **Custom** → `NEW` only. Return Traffic **off** |
| `Allow Main to IoT` | ALLOW | zone `Internal`, network `Main` | zone `IoT`, Any | **Already exists** (created 2026-09-08, index 10000) — *edit its destination zone*, do not duplicate |
| `Allow Private Servers to IoT` | ALLOW | zone `Internal`, network `Private Servers` | zone `IoT`, Any | Home Assistant `192.168.5.226` |
| `Allow Guest to TVs` | ALLOW | zone `Hotspot`, network `Guest` | zone `IoT`, IP group `TV Media Endpoints` | protocol all |

All three ALLOWs get **Allow Return Traffic** on; the BLOCK does not.

**Why the BLOCK is scoped to `NEW`.** `global_network.default_security_posture` on this site is `ALLOW_ALL`, so creating the `IoT` zone does *not* by itself gate anything — a new zone pair permits everything until a policy says otherwise. And policy ordering is unmanageable (`index` is controller-assigned, #348), so a blanket `BLOCK IoT → Internal` might land ahead of the return-traffic companion that `create_allow_respond` generates and kill replies to Main-initiated sessions. Matching only `NEW` is order-independent: IoT can never initiate inward, established/related returns always pass.

**What is already true and needs no change:** the Gateway mDNS Proxy is `mode: "all"`, `enabled_for: "all"` — every service reflected across every network, Guest included. Discovery of the TVs from Guest already works; what was missing was the unicast permission to actually stream to them.

**Home Assistant stays on Private Servers (VLAN 5)**, decided 2026-09-09. Same-VLAN traffic never reaches the gateway, so moving it onto IoT would expose its admin UI and device credentials to every bulb and TV with no policy able to filter it. If an integration genuinely needs to be on-link, give HA a second VLAN-6-tagged interface for discovery rather than relocating it.

---

## Session 2026-09-08

Authorised by the user for this task list. Six changes, all verified after writing.

### 1. Global 802.1X fallback VLAN → Guest

| | |
|---|---|
| **Where** | Settings → Networks → Global Switch Settings → 802.1X Control |
| **Key** | `global_switch.dot1x_fallback_networkconf_id` |
| **Endpoint** | `POST /api/s/default/set/setting/global_switch` |
| **Before** | `""` (no fallback network) |
| **After** | Guest (`6a9d34da3346f05e9f31efe6`, VLAN 3) |
| **Codifiable?** | **No.** `unifi_setting` exposes no switch/dot1x block at v0.55.0, and there is no `unifi_setting_switch` resource. Tracked by the commented block in `tofu/unifi/system/settings.tf`. |

**This is the fix for the "unauthenticated clients get no DHCP" problem.** A port whose profile sets `dot1x_ctrl = "auto"` stays *unauthorized* until 802.1X succeeds, and an unauthorized port drops everything — including the DHCP handshake. The intended "if they don't authenticate, put them on VLAN 3" behaviour is not a port-profile property; it is this single site-wide fallback VLAN, and it was empty. Setting it to Guest gives:

- supplicant passes 802.1X → RADIUS returns `Tunnel-Private-Group-ID = 2` → **Main (VLAN 2)**
- supplicant fails, or the device has no supplicant at all → **Guest (VLAN 3)**, with DHCP

Note this is site-wide, so it applies to every 802.1X-controlled port. Only the `Host Device` profile uses `dot1x_ctrl = "auto"` (the `UniFi Device` profile is `force_authorized`), so in practice it only affects the USW Pro Max 24 PoE access ports.

### 2. "Host Device" port profile — native VLAN Guest → Main

| | |
|---|---|
| **Where** | Settings → Profiles → Port → Host Device |
| **Endpoint** | `PUT /api/s/default/rest/portconf/<id>` |
| **Before** | `native_networkconf_id` = Guest, `setting_preference` = manual |
| **After** | `native_networkconf_id` = **Main**, `setting_preference` = manual |
| **Codifiable?** | Yes — `tofu/unifi/core/port_profiles.tf`, `unifi_port_profile.host_device`. Applied here so live matches the code without waiting for an apply. |

With change #1 handling the unauthenticated case, the native VLAN now only governs a client that **authenticated successfully but whose RADIUS reply carried no VLAN assignment**. That should be Main, not Guest. This is not a weakening of the boundary: the native VLAN is unreachable until 802.1X has already succeeded.

Unchanged and already correct: `dot1x_ctrl = auto`, `stp_port_mode = true` (Port Mode: Edge), `setting_preference = manual`.

### 3–4. WLAN settings brought in line with the code

Applied from `tofu/unifi/wireless/wlans.tf` at the user's request, via `PUT /api/s/default/rest/wlanconf/<id>`.

| SSID | Attribute | Before | After |
|---|---|---|---|
| `StKr_IoT` | `hide_ssid` | `false` | **`true`** |
| `StKr_IoT_2.4GHz` | `wpa3_support` | `true` | **`false`** |
| `StKr_IoT_2.4GHz` | `wpa3_transition` | `true` | **`false`** |
| `StKr_IoT_2.4GHz` | `pmf_mode` | `optional` | **`disabled`** |

`StKr_IoT_2.4GHz` remains `2g`-only, WPA2-PSK. Dropping WPA3 and PMF is deliberate — it exists for 2.4 GHz IoT gear that can't negotiate either.

> ⚠️ If any IoT device was associated to `StKr_IoT` by SSID broadcast, hiding the SSID may require it to be re-provisioned with the network entered manually. Nothing else about that SSID changed.

### 5. AP LEDs off

| | |
|---|---|
| **Endpoint** | `PUT /api/s/default/rest/device/<id>` with `{"led_override": "off"}` |
| **Before** | Living Room U7-Pro = `on`, Bedroom U7-Pro = `on` |
| **After** | both = **`off`** |
| **Codifiable?** | Yes — now declared as `led_override = "off"` on both AP resources. Upstream #337 (LED fields dropped from the update PUT) was fixed in v0.54.0, so this one really does apply. |

This closes the discrepancy found in the drift report: the rebuild checklist said the LEDs had been disabled, but both APs were reporting `led_override = "on"`.

### 6. Firewall policy "Allow Main to IoT" created

| | |
|---|---|
| **Endpoint** | `POST /v2/api/site/default/firewall-policies` |
| **Result** | `201`, `_id` `6a9f35ba40324b4491442e21`, controller-assigned `index` 10000 |
| **Codifiable?** | Yes — mirrors `unifi_firewall_policy.allow_main_to_iot` in `tofu/unifi/security/firewall.tf`. |

```
Allow Main to IoT | ALLOW | BOTH | protocol all | create_allow_respond | logging off
  source:      zone Internal, matching_target NETWORK, networks [Main]
  destination: zone Internal, matching_target NETWORK, networks [IoT]
  schedule:    ALWAYS
```

It was the **only** non-predefined policy on the controller (88 predefined). `index` is controller-assigned and read-only — ordering cannot be managed through the provider at all (upstream #348), so it landed at 10000 in the Internal→Internal pair.

### Verified end state

```
1. 802.1X fallback VLAN = Guest      [dot1x_portctrl_enabled=true]
2. Host Device native = Main, dot1x=auto, stp_port_mode=true, pref=manual
3. StKr_IoT hide_ssid = true
4. StKr_IoT_2.4GHz wpa3=false transition=false pmf=disabled bands=2g
5. AP LEDs: Bedroom U7-Pro=off, Living Room U7-Pro=off
6. Custom firewall policies: Allow Main to IoT [idx 10000, enabled] Main -> IoT
```

### Re-verified after workstation reboot (same day)

The workstation rebooted mid-task (kernel 7.2.2 → 7.2.3). Nothing was lost: all six changes above were still present on the controller, and all five devices were online on their static addresses.

```
1. fallback VLAN = Guest | dot1x_portctrl=true
2. Host Device: native=Main dot1x=auto stp=true pref=manual
3. StKr_IoT hide_ssid = true
4. StKr_IoT_2.4GHz wpa3=false trans=false pmf=disabled bands=2g
5. AP LEDs: Bedroom U7-Pro=off, Living Room U7-Pro=off
6. custom policies: Allow Main to IoT [idx 10000, on] Main->IoT
7. devices up: Bedroom U7-Pro(ok 192.168.1.5), Living Room U7-Pro(ok 192.168.1.4),
   UDM StKr(ok 46.10.181.183), USW Aggregation(ok 192.168.1.3), USW Pro Max 24 PoE(ok 192.168.1.2)
8. port profiles: UniFi Device, Host Device
```

**The 802.1X fallback is confirmed working against a real client.** `MICHELANGELO` on Pro Max port 22 holds `192.168.3.177` on Guest — a wired client on a `dot1x_ctrl = "auto"` port with a DHCP lease, which was impossible before the fallback VLAN was set.

#### Two clients without a lease — diagnosed, fix deferred by the user

**No action was taken on either port in this session — deferred by the user at the time.** *Deferral lifted 2026-09-09: the user authorised both ports. See the "Pending — authorised 2026-09-09" section at the top of this file for the steps; the notes below are the original diagnosis and remain accurate.*

| Port | Client | Currently | **Should be** |
|---|---|---|---|
| 18 | `jetkvm-ce4ac3437e0d935d` (`30:52:53:0d:1a:68`) | VLAN 3 (Guest, via 802.1X fallback), no IP | **Private Servers (VLAN 5), fixed IP `192.168.5.23`** |
| 6 | unnamed (`b0:b3:69:41:2c:9b`) | VLAN 2 (Main), no IP | **IoT (VLAN 6)** |

*Re-read on 2026-09-09: the port-6 client had moved to Guest VLAN 3 with `192.168.3.69` — i.e. the 802.1X fallback caught it once its lease attempt on Main expired — and it identifies as an `SDMC Android TV Box DV8919`, the EON box in the living room. That makes it the wired half of the "Guest can reach the TVs" request, which is what lifted its deferral.*

Both sit on ports the controller has assigned the `Host Device` profile, and both are long enough associated that this is not DHCP still in flight. Every port checked (6, 18, 19, 22) reports `dot1x_mode = "auto"`, `dot1x_status = "authorized"` — note that a port authorised *into the fallback VLAN* also reads `authorized`, so that field does not distinguish "passed 802.1X" from "fell back".

This looks like a symptom of the **still-open port-override drift** (§3.4 of the drift report), not of anything changed today:

- In code, port 18 is `BR-02` on Public Servers and port 6 is `LR-06` on IoT — neither was ever meant to be a host port behind 802.1X.
- A JetKVM is infrastructure. The sibling `jetkvm-4562a8bf464c58c8` on port 12 (no override → VLAN 1) holds `192.168.1.127` quite happily, and `system/clients.tf` historically pinned JetKVMs to `192.168.5.20/.21` on Private Servers. The one on port 18 is very likely statically configured for a subnet it can no longer reach from Guest.

Confirmed by the user. Both are infrastructure that should never have been behind `Host Device`/802.1X in the first place — they belong on the per-VLAN profiles that the factory reset destroyed. Two knock-on notes for whoever picks this up:

- **Port 18's target differs from the code.** `devices/usw_pro_max_24_poe.tf` had port 18 as `BR-02` with an inline native VLAN of **Public Servers**; the intended network is **Private Servers**. **Resolved 2026-09-09** in code — the block now uses `port_profile_id = var.port_profile_private_servers_id`. The controller side is step 3 of the pending checklist.
- **`192.168.5.23` is a third JetKVM.** `system/clients.tf` pins JetKVMs at `.20` (`38:52:53:0a:09:87`) and `.21` (`30:52:53:08:45:16`); `30:52:53:0d:1a:68` is neither. It needs its own `unifi_client` entry — still blocked by §14.5, so as of 2026-09-09 the reservation is deliberately controller-only and no resource was added.
- Port 6's target (IoT) already matches what the code says (`LR-06`, IoT profile), so only the controller is out of step there.

### 7. `StKr_IoT_2.4GHz` hidden (later the same day)

| | |
|---|---|
| **Endpoint** | `PUT /api/s/default/rest/wlanconf/<id>` |
| **Attribute** | `hide_ssid` |
| **Before** | `false` |
| **After** | **`true`** |
| **Codifiable?** | Yes — `hide_ssid = true` set in `tofu/unifi/wireless/wlans.tf`, `unifi_wlan.stkr_iot_2_4ghz`. Applied here as well so live matches the code without waiting for an apply. |

Both IoT SSIDs are now hidden:

```
StKr_IoT:        hide_ssid=true  bands=2g/5g/6g
StKr_IoT_2.4GHz: hide_ssid=true  bands=2g
```

> ⚠️ Same caveat as change #3: any 2.4 GHz IoT device that joined by picking the SSID from a scan list will now need the network entered manually if it is ever re-provisioned. Already-associated devices keep working — nothing but the beacon changed.

### Not changed

Read-only inspection only; no writes were made to networks, port overrides, devices other than the two APs, port forwards, clients, RADIUS users, or the site RADIUS secret.
