# UniFi controller — changes made through the browser

Every change made to the live controller (`https://192.168.1.1`, site `default`) outside of OpenTofu is logged here, newest session first. Anything in this file is **drift by construction**: it exists on the controller and is either not expressible in the pinned provider, or is waiting for a `tofu apply` from the management plane.

Changes were made through the user's authenticated Chrome session against the controller's own REST API (`/proxy/network/api/s/default/...` and `/proxy/network/v2/api/site/default/...`) — the same endpoints the UniFi web UI uses. Each write was a read-modify-write of the full object, followed by a read-back to verify.

---

## Session 2026-09-13

Eight topics (the UDM overrides were added on request after the USW pass; port forwards were a read-only diff; BPDU Guard was the last change of the day). RADIUS and the port profiles were read-only verifications of changes the user made in the UI; the Gateway mDNS Proxy, Pro Max port 12 (+ one client fixed IP) and the **USW port override alignment** were **changed** (each authorised by the user).

### BPDU Guard enabled on the three host-facing port profiles

| | |
|---|---|
| **Where** | Settings → Overview → Port Profiles → *Host Device*, *Private Server*, *IoT Device* → Services → BPDU Guard |
| **Endpoint** | `PUT /api/s/default/rest/portconf/<id>` × 3, read-modify-write of the full profile with `stp_bpdu_guard_enabled: true` |
| **Before** | `false` on all five profiles |
| **After** | **`true`** on Host Device, Private Server, IoT Device; `false` on UniFi Device (deliberately — inter-switch/AP links carry BPDUs) and Public Server (no ports assigned, left as is) |
| **Codifiable?** | **No.** `unifi_port_profile` has no `stp_bpdu_guard_enabled`; recorded as `FIXME(unifi-ui-only)` in `core/port_profiles.tf`. |

Recommended and authorised in conversation: every port on these profiles is an end host, so a BPDU arriving means a rogue switch or a bridging host, and the guard err-disables the port rather than letting STP renegotiate around it. This also restores the protection Aggregation port 1 had under its old inline override. Read-back verified all other profile fields unchanged.

### Port forwards — read-only diff, code reduced to live

`GET /rest/portforward`: one rule, `NGINX Server`, tcp_udp, wan any:80,443 → 192.168.5.58:80,443. Code had six resources; trimmed to that one rule (details in the drift report §8). No writes.

### USW Pro Max + USW Aggregation port overrides — aligned to the code's intent

Authorised by the user ("use the names from the code… 9, 10, 11 default settings but disabled… Aggregation 2–7 disabled, port 8 renamed, port 1 on a profile; don't touch the UDM").

| Device | Endpoint | Result |
|---|---|---|
| USW Pro Max 24 PoE | port 9: **UI** (Port Manager → Port 9 → Port Profile off → Port State Disabled → Apply) to learn the stored shape; then `PUT /rest/device/<id>` with the full 25-entry `port_overrides` array | `200`. Renamed 1–5, 7, 8, 13–17, 19–24, 26 to the code's labels; 10 and 11 written as byte-identical copies of the UI-made port 9. 6/12/18/25 untouched. Read back: 25 overrides, disabled trio identical, every other override unchanged except `name`. |
| USW Aggregation | `PUT /rest/device/<id>` with the full 8-entry array | `200`. Port 1 inline override → `{name "Servacho-Gosho", portconf_id Private Server, setting_preference auto}`; 2–7 → disabled shape, `SFP+ N`; 8 → `UDM-Pro-Max`. Read back OK; Servacho-Gosho still `192.168.5.10` on port 1. |
| UDM StKr *(later the same day, on request)* | port 2: **UI** (Port State Disabled → Apply) to learn the gateway's stored shape; then `PUT /rest/device/<id>` with the full 9-entry array | `200`. Ports 3–8 written as identical copies of port 2; port 11 renamed `USW-Aggregation`; port 10 untouched (`SFP+ 1`, UniFi Device). Ports 1/9 (WAN) untouched — no override exists or should. Read back: the seven disabled ports identical, 10/11 intact, ports 1/9/10/11 `up`, all downstream devices `state 1`. |

**Aggregation port 1 — what the profile switch changed.** The old inline override and the Private Server profile agree on native Private Servers, `dot1x_ctrl force_authorized`, `stp_edge_state enabled`, `tagged_vlan_mgmt auto`, `stp_port_mode true`, `lldpmed_enabled true`, and all the off-by-default knobs. The one real difference: the inline override had **`stp_bpdu_guard_enabled = true`** and the profile has it `false`, so BPDU Guard on Servacho-Gosho's uplink is now off. It is a UI-only field on the profile (no provider attribute); if it should stay on, enable it on the *Private Server* profile — which would also cover the two JetKVM ports 12 and 18.

**Disabled shape** (recorded once, in the drift report §3.4): `forward "disabled"` + `port_security_enabled true` + `port_security_mac_address []` + `tagged_vlan_mgmt "block_all"` + no native network + `setting_preference "manual"` + carried-over defaults.

### USW Pro Max ports 6, 12, 18 — 6 and 18 read back; **port 12 set via the API**

| Port | Live override | Client | Code now |
|---|---|---|---|
| 6 | `IoT Device`, poe auto, pref manual | Living Room TV `b0:b3:69:41:2c:9b`, fixed `192.168.6.10` | mirrors live |
| 12 | was **none** → now `Private Server`, poe auto, pref manual | `jetkvm-4562a8bf464c58c8` `30:52:53:0a:09:87`, was `192.168.1.127` on UniFi Devices → fixed `192.168.5.20` on Private Servers | mirrors live |
| 18 | `Private Server`, poe auto, pref manual | `jetkvm-ce4ac3437e0d935d` `30:52:53:0d:1a:68`, fixed `192.168.5.23` | mirrors live |

Port 12 write, authorised by the user:

| | |
|---|---|
| **Endpoint 1** | `PUT /api/s/default/rest/device/<pro-max-id>` with the full `port_overrides` array: the existing 24 entries plus `{port_idx 12, name "Port 12", poe_mode auto, setting_preference manual, portconf_id <Private Server>}` (same shape as port 18) — `200` |
| **Endpoint 2** | `PUT /api/s/default/rest/user/<client-id>` for `30:52:53:0a:09:87` with `use_fixedip true, fixed_ip 192.168.5.20, network_id <Private Servers>` — `200` |
| **Read-back** | port 12 override exactly as sent; 25 overrides total; every other override's profile, name, PoE and preference unchanged (two key sets only, both pre-existing — ports 23/24/26 have no `poe_mode`); port 12 `portconf` = Private Server, `dot1x force_auth authorized`. Client: `use_fixedip true`, `192.168.5.20`, Private Servers. |

Because a full-array `PUT` is exactly how upstream #430 flattens switches, every other override was diffed after the write — nothing was stripped. The switch now has 25 overrides live (every port except 25). Fixed IPs live are now seven: `.5.10`, `.5.200`, `.5.201`, `.5.215`, `.5.23`, `.6.10` Living Room TV, `.6.11` Bedroom TV.

### Per-VLAN port profiles — created by the user, replicated in code (read-only)

The user recreated the three profiles the factory reset destroyed. Read via `GET /api/s/default/rest/portconf`:

| Name | forward | native | 802.1X | pref | STP port mode |
|---|---|---|---|---|---|
| `Public Server` | customize | Public Servers | `force_authorized` | manual | true |
| `Private Server` | customize | Private Servers | `force_authorized` | manual | true |
| `IoT Device` | customize | IoT | `force_authorized` | manual | true |

`core/port_profiles.tf` was aligned: names (the old code had the plural `Public Servers` / `Private Servers` and bare `IoT`), `setting_preference = "manual"`, `stp_port_mode = true`. Resource addresses unchanged. No writes to the controller.

A second pass walked every field of the profile editor side panel (Settings → Overview → Port Profiles → *Public Server*) against the API object and the provider schema — table in the drift report §2. Outcome: everything the provider can express is in code; Port Mode: Edge (`stp_edge_state`), Flow Control, PTP, QoS, STP Uplink/BPDU Guard, Link Debounce, EEE and Multicast Router Port have no provider attribute and are UI-only. Also corrected: `stp_port_mode` is the Services → STP toggle, not Port Mode: Edge.


### Gateway mDNS Proxy — factory `all` → Custom, Main + IoT, 19 services

| | |
|---|---|
| **Where** | Settings → Networks → Global → Gateway mDNS Proxy |
| **Key** | site setting `mdns` |
| **Endpoint** | `POST /api/s/default/set/setting/mdns` (plus one UI-driven apply, see below) |
| **Before** | `mode: all`, `enabled_for: all`, no VLAN scope, no service list — the factory default |
| **After** | `mode: custom`, `enabled_for: some`, `enabled_for_network_ids: [Main, IoT]`, 19 `predefined_services` |
| **Codifiable?** | **No.** No `unifi_setting_mdns` resource at v0.55.0. Runbook lives in `tofu/unifi/system/mdns.tf`, now with the full 25-entry identifier catalogue and the wire format. |

Decided by the user: services = casting/media/smart-home plus Apple File Sharing and iTunes; VLAN scope = **Main + IoT only** (Guest deliberately excluded). Dropped from the 25-service default: `apple_iChat`, `ftp_servers`, `ssh_servers`, `time_capsule`, `web_servers`, `windows_file_sharing_samba`.

Kept (19): `amazon_devices`, `android_tv_remote`, `apple_airDrop`, `apple_airPlay`, `apple_file_sharing`, `apple_iTunes`, `aqara`, `bose`, `dns_service_discovery`, `google_chromecast`, `homeKit`, `matter_network`, `philips_hue`, `printers`, `roku`, `scanners`, `shelly`, `sonos`, `spotify_connect`.

How it actually went, for the record:

1. Service identifiers were read from the UI's Custom-mode picker (checkbox ids) — they are mixed-case (`apple_airPlay`, `homeKit`), not the snake_case the old `mdns.tf` guessed.
2. A first API write with `enabled_for: "custom"` and string service ids was rejected `400 api.err.InvalidPayload`; read-back confirmed nothing changed.
3. To learn the real schema, an in-page interceptor was installed and the UI form was driven to Custom / Main + IoT / Specific and applied. **The interceptor was bypassed** (the app holds its own `fetch` reference) and the UI write went through for real — landing at the intended scope but with all 25 default services. Harmless intermediate state, but it was a write.
4. From that read-back the wire format was clear: `enabled_for: "some"`, `predefined_services: [{"code": …}]`. A second API write filtered the list to the 19 above: `200`.
5. Verified after a page reload: `mode custom | enabled_for some | vlans IoT+Main | services 19 | custom 0`.

**Side effect worth knowing:** per-network `mdns_enabled` flipped from `true` on all eight networks to `true` on exactly Main and IoT. The flag is derived from the site-wide scope — `core/networks.tf` was updated to mirror it (`guest` `true → false`; all `TODO(mdns)` markers removed).

### RADIUS users `vl.penchev` and `v.todorova` — created by the user, verified against code (read-only)

The user created both accounts by hand in Settings → Profiles → RADIUS → Users, then asked for a live-vs-tofu comparison. Read via `GET /api/s/default/rest/account` from the logged-in session:

| Account | tunnel_type | tunnel_medium_type | vlan | group_policy |
|---|---|---|---|---|
| `a.penchev` | 13 | 6 | 2 | GLOBAL |
| `e.pencheva` | 13 | 6 | 2 | GLOBAL |
| `v.todorova` | 13 | 6 | 2 | GLOBAL |
| `vl.penchev` | 13 | 6 | 2 | GLOBAL |

All four match `local.radius_users` in `tofu/unifi/security/radius.tf` attribute for attribute; the new pair is indistinguishable from the pre-existing pair. Nothing to change on either side. The user confirmed both also have entries in the Vault `unifi/radius/users` secret. The `TODO(radius-users)` comment in that file is closed; what is left is the `tofu import` every resource on the rebuilt controller needs, now a `TODO(import)`.

Also read (unchanged since 2026-09-08): the `Default` RADIUS profile — `vlan_enabled = true`, `vlan_wlan_mode = optional`, acct on 1813, interim update 3600 s.

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

**No action taken on either port. Explicitly deferred — do not change ports 6 or 18 until asked.**

| Port | Client | Currently | **Should be** |
|---|---|---|---|
| 18 | `jetkvm-ce4ac3437e0d935d` (`30:52:53:0d:1a:68`) | VLAN 3 (Guest, via 802.1X fallback), no IP | **Private Servers (VLAN 5), fixed IP `192.168.5.23`** |
| 6 | unnamed (`b0:b3:69:41:2c:9b`) | VLAN 2 (Main), no IP | **IoT (VLAN 6)** |

Both sit on ports the controller has assigned the `Host Device` profile, and both are long enough associated that this is not DHCP still in flight. Every port checked (6, 18, 19, 22) reports `dot1x_mode = "auto"`, `dot1x_status = "authorized"` — note that a port authorised *into the fallback VLAN* also reads `authorized`, so that field does not distinguish "passed 802.1X" from "fell back".

This looks like a symptom of the **still-open port-override drift** (§3.4 of the drift report), not of anything changed today:

- In code, port 18 is `BR-02` on Public Servers and port 6 is `LR-06` on IoT — neither was ever meant to be a host port behind 802.1X.
- A JetKVM is infrastructure. The sibling `jetkvm-4562a8bf464c58c8` on port 12 (no override → VLAN 1) holds `192.168.1.127` quite happily, and `system/clients.tf` historically pinned JetKVMs to `192.168.5.20/.21` on Private Servers. The one on port 18 is very likely statically configured for a subnet it can no longer reach from Guest.

Confirmed by the user. Both are infrastructure that should never have been behind `Host Device`/802.1X in the first place — they belong on the per-VLAN profiles that the factory reset destroyed. Two knock-on notes for whoever picks this up:

- **Port 18's target differs from the code.** `devices/usw_pro_max_24_poe.tf` currently has port 18 as `BR-02` with an inline native VLAN of **Public Servers**; the intended network is **Private Servers**. Fix the code as part of the §3.4 port-override work, not just the controller.
- **`192.168.5.23` is a third JetKVM.** `system/clients.tf` pins JetKVMs at `.20` (`38:52:53:0a:09:87`) and `.21` (`30:52:53:08:45:16`); `30:52:53:0d:1a:68` is neither. It needs its own `unifi_client` entry — which is itself blocked, see §14.5 of the drift report.
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
