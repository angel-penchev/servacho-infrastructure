# UniFi controller — changes made through the browser

Every change made to the live controller (`https://192.168.1.1`, site `default`) outside of OpenTofu is logged here, newest session first. Anything in this file is **drift by construction**: it exists on the controller and is either not expressible in the pinned provider, or is waiting for a `tofu apply` from the management plane.

Changes were made through the user's authenticated Chrome session against the controller's own REST API (`/proxy/network/api/s/default/...` and `/proxy/network/v2/api/site/default/...`) — the same endpoints the UniFi web UI uses. Each write was a read-modify-write of the full object, followed by a read-back to verify.

---

## Session 2026-09-11 — Guest access to the TVs abandoned and rolled back

The functional test finally ran, and the feature failed it. Guest clients could not cast; the cause turned out to be structural, and the user then decided guests should not reach the TVs at all. **Everything specific to Guest→TV access has been removed from the controller and from the code.**

### What the test showed, in order

1. **Discovery failed, but mDNS was not the reason.** The reflector was measurably working throughout: `Hotspot → Gateway: Allow mDNS` had **337,966 hits** ticking over live, `IoT → Gateway: Allow mDNS` **127,493**. The Auto tooltip reads "Automatically allows all services across all VLANs", and the Custom picker lists Guest (3) as eligible. Nothing about mDNS needed changing — the earlier assumption that guest networks are excluded from the reflector is **wrong**.
2. **The blocker was `l2_isolation`** (Client Device Isolation) on the `StKr_Guest` WLAN, dropping the reflected multicast at the AP. UniFi's own tooltip on that checkbox warns it "may inhibit the functionality of AirPlay, **Chromecast**, Sonos devices, screen mirroring, and wireless printers". Turning it off made the TVs appear as cast targets.
3. **Casting still did nothing** — and this is the structural part. **For a guest network the zone firewall is not the enforcement point.** After repeated cast attempts *and* direct `http://192.168.6.10:8008` / `.11:8008` requests from a Guest phone, all three Hotspot → IoT policies read **exactly zero hits**: `Allow Guest to TVs`, the predefined `Post-Authorization Restrictions`, and `Block All Traffic`. A packet reaching the gateway increments one of them. None did. The access points drop guest traffic to RFC1918 locally, ahead of and independently of any policy.

   Hit counters are only present on the policy object when non-zero (`hits` / `last_hit` are absent at zero), which is how this was measured — `Allow Main to IoT` carried `hits: 13373` at the same moment.

4. Guest clients still reported **`is_guest: true`** even after the WLAN's Application was switched to Standard, because the flag follows the **network's** `purpose = "guest"`, i.e. its membership of the Hotspot zone. Making Guest→TV work would have meant moving the Guest network into a custom zone and re-pointing the policy — trading UniFi's built-in guest isolation for hand-written policy. **Declined.**

### Rolled back

| # | What | Result |
|---|---|---|
| 1 | `StKr_Guest` → **Client Device Isolation re-enabled** | `l2_isolation: true`. Security untouched: `wpapsk`, passphrase intact |
| 2 | Firewall policy **`Allow Guest to TVs` deleted** | Gone, and deleting the parent removed the auto-generated `Allow Guest to TVs (Return)` companion too |
| 3 | Address group **`TV Media Endpoints` deleted** | No firewall groups remain; it existed only for that policy |

Remaining custom policies: `Allow Main to IoT` (idx 10000) and `Allow Private Servers to IoT` (idx 10001). Both TVs still hold their reservations (`192.168.6.10` / `192.168.6.11`) — those were left alone, they are just no longer reachable from Guest.

### ⚠️ Not restored — needs the guest Wi-Fi password

`StKr_Guest` is still **`is_guest: false`** (Application = Standard rather than Hotspot).

**Selecting Application = Hotspot in the UI silently resets Security Protocol to `Open` and blanks the passphrase**, and switching the protocol back to WPA2/WPA3 does *not* restore it — the password field comes back empty with "Must have at least 8 characters". Applying that would have turned the guest SSID into an open network. I cancelled instead, twice, and verified `security: wpapsk` with the passphrase intact each time.

To finish, someone with the password must: WiFi → `StKr_Guest` → Application → **Hotspot**, then set Security Protocol back to **WPA2/WPA3** and **re-enter the guest password** before Apply.

In practice the gap is small: guest isolation is enforced from the network's `purpose = "guest"` / Hotspot-zone membership, which never changed, and step 1 above restored client isolation. The `is_guest` WLAN flag mainly governs the Hotspot Portal association.

---

## Session 2026-09-10 — Bedroom TV reservation moved to the hardware MAC

Follow-up to the 2026-09-09 session, Outstanding item 2. The user turned MAC randomization off on the Sony BRAVIA, rejoined `StKr_IoT` and rebooted the TV — and it stayed on `192.168.6.93`.

**Cause: the reservation was orphaned, not broken.** Turning randomization off swaps the randomized MAC for the burned-in one, so the TV became a *different client* as far as the controller is concerned:

| | Old | New |
|---|---|---|
| MAC | `52:4b:e7:7b:a6:c7` | **`f4:4e:b4:73:bf:19`** |
| U/L bit | locally administered (`0x52 & 0x02 == 2`) | **universally administered** (`0xF4 & 0x02 == 0`) |
| OUI | — (randomized) | `F4:4E:B4` Cloud Network Technology Singapore (Foxconn) |
| Client record | `6a9c9a533346f05e9f318738`, held `fixed_ip 192.168.6.11` | `6aa15f8b40324b4491455979`, created on re-join, no reservation |

So `.6.11` was pinned to a MAC that no longer appears on the network, and the MAC that does appear had no reservation — it took a pool address.

### Changes

| # | Where | Client | Change |
|---|---|---|---|
| 1 | Client Devices → old record → Settings | `52:4b:e7:7b:a6:c7` | **Fixed IP Address unchecked** (`use_fixedip` → `false`), renamed to `Bedroom TV (retired random MAC)`. Unchecked rather than Removed — non-destructive, and it frees `.6.11` just the same. Note the controller retains the now-inert `fixed_ip` string on the object; only `use_fixedip` governs. |
| 2 | Client Devices → new record → Settings | `f4:4e:b4:73:bf:19` | Named **`Bedroom TV`**, **Fixed IP Address = `192.168.6.11`**. The field prefills with the *current lease* (`.6.93`), so it must be overtyped — verified by zoom before applying. |
| 3 | Client Devices → Quick Actions | `f4:4e:b4:73:bf:19` | **Reconnect** — forced re-association, which is what made the TV pick up the reservation. |

### Result — both TVs on their reserved addresses

```
Living Room TV  b0:b3:69:41:2c:9b  192.168.6.10  vlan 6   (EON box, wired Pro Max port 6)
Bedroom TV      f4:4e:b4:73:bf:19  192.168.6.11  vlan 6   (Sony BRAVIA, StKr_IoT)
```

Also verified: exactly seven reservations, `f4:4e:b4:73:bf:19 → 192.168.6.11` replacing the old entry; `TV Media Endpoints` still `{192.168.6.10, 192.168.6.11}`; `Allow Guest to TVs` enabled at index 10000. **The address group now matches both TVs, so the Guest cast test can be run in full.** *(The group and policy were deleted on 2026-09-11 — see the session above. The reservations themselves stand.)*

**Timing note, worth remembering.** Reconnect is not instant and it is not synchronous with re-association. Immediately after the click the TV was back on the AP (uptime reset to 66s) but *still on `192.168.6.93`* — it had re-associated at L2 while carrying its old IP configuration over. It only moved to `.6.11` on a later poll, around 200s of uptime. Do not conclude from one read that a reservation has failed to take; poll for a couple of minutes first. Had it not moved, the fallbacks were to forget `StKr_IoT` on the TV and rejoin (forces a DHCPDISCOVER; safe now that randomization is off, since forgetting can no longer mint a new random MAC), or to wait out `dhcpd_leasetime = 86400` and let RENEWING at T1 ≈ 12h get NAKed onto `.6.11`.

**Codifiable? No** — same #428 block as every other reservation.

---

## Session 2026-09-09 — Guest access to the two TVs, plus ports 6 and 18

Authorised by the user ("do it via the Chrome connection"). Applied through the admin panel UI, each change read back against the REST API afterwards. The OpenTofu side is in `security/firewall.tf`, `core/port_profiles.tf`, `devices/usw_pro_max_24_poe.tf` and `system/mdns.tf`.

**Goal:** Guest (VLAN 3) reaches exactly two IoT devices — the living-room EON box and the bedroom Sony BRAVIA — while IoT cannot initiate anything towards Main or Private Servers.

### 0. The finding that reshaped the work

The intended asymmetry was never in force. IoT and Main both sat in the **Internal** zone, and the Zone Matrix showed `Internal → Internal = Allow All` — so **IoT → Main was wide open**, and the `Allow Main to IoT` policy created on 2026-09-08 (index 10000, 2,996 hits) had never needed to match anything.

**Correction to an earlier assumption.** Planning notes for this change claimed that because `global_network.default_security_posture` is `ALLOW_ALL`, a newly created zone pair would default to *allow* and would therefore need an explicit `NEW`-only BLOCK policy. **That is wrong.** The Create Zone dialog states it plainly — *"newly created zones are blocked from accessing all other zones except External and Gateway by default"* — and the live policy table confirmed it immediately after the zone was created:

| Pair | Predefined policy | Index |
|---|---|---|
| `IoT → Internal` | **BLOCK** Block All Traffic | 2147483647 |
| `IoT → Hotspot` / `Vpn` / `Dmz` | **BLOCK** Block All Traffic | 2147483647 |
| `IoT → External` | ALLOW Allow All Traffic | 2147483647 |
| `IoT → Gateway` | ALLOW Allow All Traffic + **Allow mDNS** | 2147483647 / 30000 |

So the asymmetry comes from the zone boundary itself, and **no explicit block policy was created** — it would duplicate a predefined rule. `ALLOW_ALL` governs the built-in zones' predefined policies, not user-created ones. Custom policies land at index ~10000, far ahead of the catch-all block at 2147483647, so ordering between them is not in question either.

### 1. Three port profiles created

Settings → Profiles → Port → Create New, in VLAN-ID order.

| Name | Native VLAN | 802.1X | id |
|---|---|---|---|
| `Public Server` | Public Servers (4) | Force Authorized | `6aa12b2a40324b449145290b` |
| `Private Server` | Private Servers (5) | Force Authorized | `6aa12ba440324b449145295b` |
| `IoT Device` | IoT (6) | Force Authorized | `6aa12c4e40324b44914529f2` |

All three: `forward = customize`, `poe_mode = auto`, `autoneg`, `tagged_vlan_mgmt = auto`, `port_security_enabled = false`, `stp_port_mode = true`, `setting_preference = manual`.

**Codifiable?** Yes, except `stp_edge_state` — see step 2.

### 2. Port Mode set to Edge on all three (follow-up fix)

The UI creates profiles as **Infrastructure**, and ports 6 and 18 consequently showed STP role *Participant* while the other 20 host ports show *Edge*. That is wrong for a single-host access port: a non-Edge port runs full STP and holds the link in listening/learning for ~15–30s after link-up, dropping the DHCP handshake. All three were switched to **Edge** to match `Host Device`.

Diffing two live profiles that differ only in that toggle identified the field: **`stp_edge_state`** (`enabled` = Edge, `disabled` = Infrastructure). This also disproves the long-standing comment in `core/port_profiles.tf` claiming `stp_port_mode = true` meant "Port Mode: Edge" — `stp_port_mode` is the plain STP checkbox and is `true` on all five profiles.

**Codifiable? No.** go-unifi carries `StpEdgeState` (`unifi/port_profile.generated.go`) but the provider does not expose `stp_edge_state` on `unifi_port_profile` at v0.55.0. **Provider-only PR needed** — unlike the mDNS gap, which needs both repos. Recorded as a `FIXME(unifi)` in `core/port_profiles.tf`. Note `UniFi Device` stays non-Edge deliberately: it is for switch-to-switch uplinks, where STP participation is the point.

### 3. Ports 6 and 18 reassigned

UniFi Devices → USW Pro Max 24 PoE → Port Manager. **This retires the "do not change ports 6 or 18" deferral in full.**

| Port | Was | Now | Device |
|---|---|---|---|
| 6 | `Host Device` | **`IoT Device`** | `SDMC Android TV Box DV8919` (EON), `b0:b3:69:41:2c:9b` |
| 18 | `Host Device` | **`Private Server`** | `jetkvm-ce4ac3437e0d935d`, `30:52:53:0d:1a:68` |

Both devices had been fallback-dumped onto Guest by the site-wide 802.1X fallback, because `Host Device` uses `dot1x_ctrl = auto` and neither has a supplicant. Neither port draws PoE (`poe_power = 0`), so both devices are self-powered and a port power-cycle cannot restart them.

**Codifiable?** Only nominally — `devices/usw_pro_max_24_poe.tf` records the intent, but all three switch resources carry `lifecycle { ignore_changes = [port_override] }` because of #430 / #438, so no apply pushes port assignments.

### 4. Three fixed-IP reservations

Client Devices → client → Settings → Fixed IP Address.

| Client | MAC | Fixed IP | Result |
|---|---|---|---|
| `Living Room TV` (renamed, was unnamed) | `b0:b3:69:41:2c:9b` | `192.168.6.10` | ⚠️ on VLAN 6 but **no lease yet** — see Outstanding |
| `Bedroom TV` (renamed, was unnamed) | `52:4b:e7:7b:a6:c7` | `192.168.6.11` | ⚠️ **superseded 2026-09-10** — randomization was turned off, so the TV now presents `f4:4e:b4:73:bf:19` and the reservation was moved to that MAC. See the 2026-09-10 session |
| `jetkvm-ce4ac3437e0d935d` | `30:52:53:0d:1a:68` | `192.168.5.23` | ✅ **moved to VLAN 5 / `192.168.5.23`** — a device that previously had no usable address at all |

**Codifiable? No.** Every in-place `unifi_client` update fails at v0.55.0 (`inconsistent result after apply: .last_ip`, #428, merged as #447, unreleased). All three stay controller-only, which is also the answer to the §14.5-blocked `.5.23` item. The firewall does not need them — it matches an address group.

### 5. `IoT` firewall zone created

Settings → Zones → Create Zone. Name `IoT`, networks: IoT. Zone id **`6aa12f7b40324b4491452cf5`**; IoT left `Internal` automatically.

The confirmation dialog warned it would *"pause the Allow Main to IoT firewall policy"*, and it did — that policy came back `enabled = false` with its destination cleared. Fixed in step 6.

**Codifiable?** Yes, but a custom zone cannot be imported by name the way built-ins can:

```
tofu import unifi_firewall_zone.iot 6aa12f7b40324b4491452cf5
```

### 6. Address group + three ALLOW policies

Address group `TV Media Endpoints` (`6aa1316d40324b4491452f98`), type `address-group`, members `192.168.6.10`, `192.168.6.11` — created inline from the policy form's IP → List → Create New.

| Policy | Source | Destination | Index |
|---|---|---|---|
| `Allow Main to IoT` *(retargeted + resumed)* | Internal / Main | zone `IoT`, Any | 10000 |
| `Allow Private Servers to IoT` *(new)* | Internal / Private Servers | zone `IoT`, Any | 10001 |
| `Allow Guest to TVs` *(new)* | Hotspot / Guest | zone `IoT`, IP list `TV Media Endpoints` | 10000 |

All three ALLOW, protocol all, IP version Both, connection state All, **Auto Allow Return Traffic on**. The `Allow Guest to TVs` destination came back as `matching_target = IP` with **`matching_target_type = OBJECT`** — exactly the derivation the provider performs from a non-empty `ip_group_id`, and what upstream #365 fixed in v0.55.0 (our pin).

`create_allow_respond` regenerated the predefined `Allow Main to IoT (Return)` companion in the `IoT → Internal` pair.

**Ordering note:** creating the zone briefly blocked Private Servers → IoT, so Home Assistant (`192.168.5.226`, confirmed live on VLAN 5) lost IoT access between steps 5 and 6. Unavoidable — an allow policy cannot reference a zone that does not exist yet. Restored by step 6.

### 7. Gateway mDNS Proxy — deliberately untouched

Re-read and left exactly as found: `mode: "all"`, `enabled_for: "all"`, `predefined_services: []`, `custom_services: []`. Every service is reflected across every network, Guest included, so discovery of the TVs from Guest needs no change; what was missing was only the unicast permission to stream to them, which step 6 adds. There is also a predefined `IoT → Gateway: Allow mDNS` policy.

> **Vindicated 2026-09-11.** Leaving mDNS alone was the right call — measured hit counters later proved the reflector was working the whole time (337,966 Hotspot→Gateway, 127,493 IoT→Gateway). The half of the sentence above that did *not* hold up is "what was missing was only the unicast permission": the unicast permission was correct and still never matched a packet, because guest traffic is dropped at the AP. See the 2026-09-11 session.

**Codifiable? No, at any level.** The provider exposes no mdns block on `unifi_setting` (v0.55.0 *or* `main`), and go-unifi's `settings.Mdns` carries only `mode` / `predefined_services` / `custom_services` — it is missing `enabled_for` and `enabled_for_network_ids`, which is what per-network scoping actually uses. **Needs a PR in both repos**; recorded as a `FIXME(unifi)` in `system/mdns.tf`, which replaced a fictional `unifi_setting_mdns` block that could never have planned.

### Outstanding — needs a physical action

1. ~~**The EON box has no lease.**~~ **Resolved** — the user power-cycled it and it came up on `192.168.6.10` / VLAN 6. (It had been holding stale Guest config on an up-and-forwarding port; neither port 6 nor 18 draws PoE, so a controller-side power cycle could not have done this.)
2. ~~**The BRAVIA's MAC is randomized.**~~ **Resolved 2026-09-10** — randomization off, hardware MAC `f4:4e:b4:73:bf:19`. That orphaned the `.6.11` reservation, which was re-pointed to the new MAC the same day; the TV now holds `192.168.6.11`. See the **2026-09-10 session** at the top of this file.
3. ~~**Functional test still to run:** from a Guest phone, confirm both TVs appear as cast targets *and* that a stream actually starts.~~ **Run 2026-09-11 — and it failed.** Targets appeared only after Client Device Isolation was turned off, and the stream never started because the APs drop guest traffic to other VLANs before the zone firewall sees it. The whole Guest→TV feature was rolled back; see the 2026-09-11 session at the top of this file.

### Also observed

- `system/clients.tf` pinned a JetKVM at `38:52:53:0a:09:87`; the live MAC on port 12 is **`30:52:53:0a:09:87`**. Confirmed a typo — the controller has never seen `38:52:...`. Corrected in code, after which the whole file was emptied: none of its ten entries matched a live reservation.
- **Power-cycled by the user, confirmed:** the EON box picked up `192.168.6.10` on VLAN 6.
- The BRAVIA associates to the **Bedroom** U7-Pro, which is correct: it is the bedroom TV. Only the EON box is in the living room.

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

**No action was taken on either port in this session — deferred by the user at the time.** *Deferral lifted 2026-09-09: the user authorised both ports. Both were applied on 2026-09-09 — see the session at the top of this file; the notes below are the original diagnosis and remain accurate.*

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

- **Port 18's target differs from the code.** `devices/usw_pro_max_24_poe.tf` had port 18 as `BR-02` with an inline native VLAN of **Public Servers**; the intended network is **Private Servers**. **Resolved 2026-09-09** in code — the block now uses `port_profile_id = var.port_profile_private_servers_id` — and on the controller, where port 18 now carries the new `Private Server` profile (step 3 of the 2026-09-09 session).
- **`192.168.5.23` is a third JetKVM.** `system/clients.tf` pins JetKVMs at `.20` (`38:52:53:0a:09:87`) and `.21` (`30:52:53:08:45:16`); `30:52:53:0d:1a:68` is neither. It needs its own `unifi_client` entry — still blocked by §14.5, so the reservation was made controller-only on 2026-09-09 and no resource was added. The device took the address and is now reachable at `192.168.5.23` on Private Servers.
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
