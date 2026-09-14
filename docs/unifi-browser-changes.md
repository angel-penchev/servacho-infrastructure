# UniFi controller — changes made through the browser

> **Layout note (2026-09-14).** The module was flattened: the `core/`, `devices/`, `security/`, `system/` and `wireless/` submodules are gone and every file now sits directly in `tofu/unifi/` (`networks.tf`, `device_*.tf`, `firewall.tf`, `settings.tf`, …; inputs, provider pin and shared data sources in `module.tf`). See `tofu/unifi/README.md` for the map. Text dated before 2026-09-14 may still use the old paths: `core/X.tf` → `X.tf`, `devices/X.tf` → `device_X.tf`, `security/X.tf` / `system/X.tf` / `wireless/X.tf` → `X.tf`; `system/etherlighting.tf` → `settings.tf`, `system/slas.tf` → `wans.tf`; the per-module `variables.tf` / `versions.tf` / `data.tf` / `outputs.tf` no longer exist.

Every change made to the live controller (`https://192.168.1.1`, site `default`) outside of OpenTofu is logged here, newest session first. Anything in this file is **drift by construction**: it exists on the controller and is either not expressible in the pinned provider, or is waiting for a `tofu apply` from the management plane.

Changes were made through the user's authenticated Chrome session against the controller's own REST API (`/proxy/network/api/s/default/...` and `/proxy/network/v2/api/site/default/...`) — the same endpoints the UniFi web UI uses. Each write was a read-modify-write of the full object, followed by a read-back to verify.

---

## Session 2026-09-14 (c) — first `tofu apply` from CI

Not a browser change but the first time code wrote to the controller, so it belongs in the same ledger. Workflow `tofu-apply.yaml`, run 34843335300, dispatched on `feat/unifi-port-config` at `2c29885` after the state cleanup and a clean plan (46 to import, 4 to change).

| Resource | Result | Read back |
|---|---|---|
| 46 imports | ✅ all in state | — |
| `unifi_wlan.stkr_guest` | ✅ `is_guest` false → **true** | `is_guest true`, `security wpapsk`, passphrase intact |
| `unifi_vpn_server.openvpn` | ✅ wrote `openvpn_mode: server` and `openvpn_encryption_cipher: AES_256_CBC` — two keys the UI never sets; the controller accepted both | both present live |
| `unifi_setting.default` | ⚠️ POST accepted, **state not saved**: "Provider produced inconsistent result after apply: `.igmp_snooping.network_ids` was null, now `[]`". Fixed in code by declaring `network_ids = []`; the next apply re-POSTs the same values | settings unchanged (they already matched) |
| `unifi_network.unifi_devices` | ❌ **`api.err.MissingIPAddress (400)`** — the provider sent `dhcpguard_enabled: true` without `dhcpd_ip_1`. Nothing changed live | `auto_scale`, `lte_lan`, `gateway_type` still absent, guarding still off |

**Follow-up the same day, through the API** (`PUT /rest/networkconf/6aa6e779e5a2f2ebb4473ca6`, two writes, both `200 ok`): first `dhcpguard_enabled: true`, `dhcpd_ip_1: 192.168.99.1`, `auto_scale_enabled: true`, `lte_lan_enabled: true`, `gateway_type: default` (read back: exactly those five keys changed); then `dhcpd_ip_2: ""`, `dhcpd_ip_3: ""` so the object has the same shape as the UI-created networks. The network now matches the other eight and the code. The plan (34843770282) **still** adds `dhcp_guarding` — not because live is wrong but because the provider's Read never fills the block on a resource whose state has it null (drift report §14.12 #14); a `state rm` + re-import of this one network closes it.

---

## Session 2026-09-14 (b) — management VLAN migration, Phase 4

Full narrative, tests and the AP-vs-switch rule in `unifi-mgmt-vlan-99-runbook.md` (Phase 4). Writes, in order, all `PUT /api/s/default/rest/device/<id>` unless noted:

| # | Write | Read-back |
|---|---|---|
| 1 | UDM `port_overrides[2]` → `{name Console, forward native, native Main, tagged block_all, pref manual, port_security off}` | stored as sent (+ `voice_networkconf_id ""`), link up 100 Mb/s |
| 2 | `POST /rest/portconf` **`UniFi Device 99`** = UniFi Device with native UniFi Devices | controller stored `forward customize` (from `all`); fixed nothing else |
| 3 | Pro Max `port_overrides[23]` → temp profile *(Test 1)* | Living Room AP stopped informing (90 s) → **reverted**, AP back in 30 s |
| 4 | Living Room AP `mgmt_network_id` → Default LAN; 8 s later Pro Max `[23]` → temp *(Test 2)* | AP `state 1` on `.99.4` after ~80 s |
| 5 | Bedroom AP same (`[24]`) | `state 1` on `.99.5` |
| 6 | Pro Max `mgmt_network_id` → Default LAN; UDM `[10]` → temp; Pro Max `[26]` → temp | **Pro Max dark** (state 7, 4 min). User moved uplink cable 26 → 25 → switch back in 30 s |
| 7 | Pro Max `mgmt_network_id` → UniFi Devices; 6 s later UDM `[10]` → UniFi Device | switch and both APs `state 1` (Phase 3 trunk restored) |
| 8 | Aggregation `[8]` → temp; 6 s later UDM `[11]` → temp | Aggregation `state 1` throughout, Servacho-Gosho present |
| 9 | Pro Max `[26]` → temp; UDM `[10]` → temp; user moved cable 25 → 26 | all four `state 1`, Pro Max uplink `port 26` |
| 10 | `PUT /rest/portconf/<UniFi Device>` native → UniFi Devices; Pro Max `[23,24,26]`, Agg `[8]`, UDM `[10,11]` → UniFi Device | profile `forward customize`, all six on it, all devices `state 1` |
| 11 | `DELETE /rest/portconf/<UniFi Device 99>` | five profiles left |
| 12 | `PUT /rest/networkconf/<Default>` `dhcpd_enabled false` | read back `false` |
| — | Living Room AP `mgmt_network_id: ""` *(cosmetic attempt)* | **rejected** `api.err.InvalidPayload`, nothing changed |

Codifiable: all of it except the temp profile (gone) — `port_profiles.tf`, `networks.tf`, `device_*.tf`. Also seen: the JetKVM on Pro Max port 12 now holds its `192.168.5.20` reservation after the user's reboot.

---

## Session 2026-09-13

Sixteen topics (the UDM overrides were added on request after the USW pass; port forwards were a read-only diff; BPDU Guard and then Phase 0 of the VLAN 99 migration closed the day). RADIUS and the port profiles were read-only verifications of changes the user made in the UI; the Gateway mDNS Proxy, Pro Max port 12 (+ one client fixed IP) and the **USW port override alignment** were **changed** (each authorised by the user).

### Management VLAN migration — Phase 0 (runbook `unifi-mgmt-vlan-99-runbook.md`)

| | |
|---|---|
| **Endpoint 1** | `PUT /api/s/default/rest/networkconf/<default-id>` — untagged Default LAN renamed `UniFi Devices` → **`Default (Untagged)`** |
| **Endpoint 2** | `POST /api/s/default/rest/networkconf` — new **`UniFi Devices`**, `vlan 99`, `192.168.99.1/24`, DHCP `.6–.254` lease 86400, mDNS off, Internal zone, corporate/LAN |
| **Read-back** | both present, VLAN 99 exactly as specified, exactly one VLAN 99 network |
| **Codifiable?** | Yes — `unifi_network.default` renamed and `unifi_network.unifi_devices` added in `core/networks.tf`. |

Two hiccups, no consequences: the first combined script threw on a cosmetic firewall-zone lookup *after* the rename and its create `POST` had already been rejected; the retry with a minimal payload succeeded but the extension filtered the response body, so success was confirmed by read-back rather than status. Devices are all still on the untagged LAN — Phases 1–4 not started.

### Management VLAN migration — Phase 1, both U7-Pro APs

| | |
|---|---|
| **Endpoint** | `PUT /api/s/default/rest/device/<id>` per AP, twice: `{mgmt_network_id: <UniFi Devices>, config_network: {type: dhcp}}`, then `config_network` static `.99.4` / `.99.5`, mask `/24`, gw + DNS `192.168.99.1` |
| **Also** | `POST /cmd/devmgr` `force-provision` and `restart` on the Living Room AP (neither helped), then `power-cycle` on Pro Max port 23 (worked). `force-provision` on the Pro Max (no effect, harmless). |
| **Read-back** | Living Room `192.168.99.4` static, Bedroom `192.168.99.5` static, both `state 1`, `mgmt_network_id` = UniFi Devices; VLAN 99 DHCP handed out `.99.39` and `.99.243` in between |
| **Codifiable?** | Yes — `mgmt_network_id` + `config_network` in `devices/u7_pro_*.tf`, new `network_unifi_devices_id` variable. |

The UI's IP Settings panel showed exactly the state the API wrote (Network Override ✓ UniFi Devices 99, DHCP), so the API path is equivalent to the UI. Wi-Fi on the Living Room AP was down ~20 min in total because of the wedged soft restart; Bedroom ~2 min.

### Management VLAN migration — Phases 2 and 3, both switches

| | |
|---|---|
| **Endpoint** | `PUT /api/s/default/rest/device/<id>` per switch, twice (DHCP on UniFi Devices, then static): Pro Max `192.168.99.2`, Aggregation `192.168.99.3`, gw + DNS `192.168.99.1` |
| **Read-back** | both `state 1` on their static address; all five devices `state 1`, four with `mgmt_network_id` = UniFi Devices (the UDM has none — it is the gateway); wired Main client, three Wi-Fi clients and Servacho-Gosho unaffected |
| **Codifiable?** | Yes — `mgmt_network_id` + `config_network` in `devices/usw_*.tf`. |

Both switches re-homed on their own within ~30 s of the DHCP write; no restarts or power cycles were needed. Phase 4 was **not** started: the Pro Max uplink (port 25) has no port profile and the laptop safety net could not be verified from here — see the runbook's Phase 4 prerequisites.

### VPN servers — OpenVPN created, WireGuard prepared

| | |
|---|---|
| **UI** | Settings → VPN → VPN Server → Create New → Other → OpenVPN: name `StKr OpenVPN Server`, everything else default (WAN1 `any`, UDP 1194, Local users = the four RADIUS accounts, Advanced Auto: `192.168.8.1/24`, Auto DNS, UDP, MTU/MSS auto) → Create |
| **API attempts first** | `POST /rest/networkconf` with `openvpn_encryption_cipher: AES_256_GCM` → `api.err.InvalidValue` (pattern `AES_256_CBC|BF_CBC`); with `AES_256_CBC` and any of `openvpn_local_port` / `openvpn_port` (number or string) → `api.err.MissingLocalPort`. Nothing was created by these. |
| **Read-back** | `vpn_type openvpn-server`, `ip_subnet 192.168.8.1/24`, `local_port 1194`, `vpn_protocol UDP`, `openvpn_interface wan`, `openvpn_local_wan_ip any`, `radiusprofile_id` = Default, `dhcpd_dns_enabled false`, `dhcpd_start/stop .8.2–.8.254`, `mss_clamp auto`, `interface_mtu_enabled false`, `openvpn_compression_disabled true`, `setting_preference auto`, no cipher field, certs/keys generated (`x_*`) |
| **Codifiable?** | Yes — `unifi_vpn_server.openvpn` in `system/vpn.tf`, plus `FIXME(unifi-ui-only)` for the fields the provider lacks. Teleport documented as a `FIXME(unifi)` block (site setting, no provider support). |

**WireGuard, second pass (same day).** The OpenBao `secret/unifi` credentials were first rejected (`AUTHENTICATION_FAILED_INVALID_CREDENTIALS` — the service account had not survived the reset). The user recreated the local admin by hand on the Admins page with the same username/password; the browser session was deliberately not used for that. Login then verified from the shell (`site_role admin`, `is_super true`), and the server was created from the shell, not the browser, so the private key never left OpenBao/`wg pubkey`:

| | |
|---|---|
| **Endpoint** | `POST /api/s/default/rest/networkconf` — `name StKr WireGuard Server`, `purpose remote-user-vpn`, `vpn_type wireguard-server`, `ip_subnet 192.168.9.1/24`, `local_port 51820`, `wireguard_interface wan`, `wireguard_local_wan_ip any`, `x_wireguard_private_key` (from OpenBao), `wireguard_public_key` (derived), `setting_preference manual` |
| **Read-back** | 200, all fields as sent, `wireguard_id 1`, in the `Vpn` zone; public key `mmWQkf3m…EKSw=` equals the one derived from the OpenBao key. `/rest/wireguardpeer` still returns `InvalidObject` on a bare GET (peers are listed per network); none exist yet. |
| **Codifiable?** | Yes — `unifi_vpn_server.wireguard` already matched; comment updated. Peers → `unifi_wireguard_peer`. |

### Pro Max port 25 disabled — 2026-09-14

| | |
|---|---|
| **Endpoint** | `PUT /api/s/default/rest/device/<pro-max-id>` with the full `port_overrides` array (read-modify-write); a new entry for `port_idx 25` copied from port 9's disabled object, `name "SFP+ 1 (Disabled)"` |
| **Read-back** | port 25 identical to port 9 except index and name; 26 overrides (was 25); port 26 still the 10 GbE uplink, all devices `state 1` |
| **Codifiable?** | Yes — new `port_override` block in `device_usw_pro_max_24_poe.tf`. Closes drift report item A4. |

### Firewall policies — read-only, code aligned — 2026-09-14

Asked to create "Allow Main to IoT", found it already there (`GET /v2/api/site/default/firewall-policies`): created 2026-09-08 (change #6 below), destination since moved from *Internal / network IoT* to the custom **IoT zone / ANY** when that zone was created on 2026-09-13, index 10000, 5 200+ hits. A second custom policy **Allow Private Servers to IoT** (index 10001, same shape, source Private Servers) exists as well. Nothing was written. `firewall.tf` now declares `unifi_firewall_zone.iot` and both policies with the live shape; drift report A3 / §7 corrected (they claimed zero custom policies).

### UDM port 2 disabled again — 2026-09-14

| | |
|---|---|
| **Endpoint** | `PUT /api/s/default/rest/device/<udm-id>` with the full `port_overrides` array (read-modify-write); the `Console` override replaced by a copy of port 3's disabled object with `port_idx 2`, `name "Port 2 (Disabled)"` |
| **Read-back** | port 2 identical to port 3 except index and name (`forward disabled`, port security on + `[]`, tagged `block_all`, pref `auto`); 9 overrides as before |
| **Codifiable?** | Yes — `device_udm_pro_max.tf` port 2 back to the disabled shape; drift report §3.2 / A5 and the runbook updated. The laptop that used the port has been unplugged. |

### UDM port 10 renamed after its peer — 2026-09-14

| | |
|---|---|
| **Endpoint** | `PUT /api/s/default/rest/device/<udm-id>` with the full `port_overrides` array (read-modify-write), only `name` of `port_idx 10` changed |
| **Before → After** | `SFP+ 1` → **`USW-Pro-Max-24-PoE`** (the device name with dashes, same convention as port 11 `USW-Aggregation`) |
| **Read-back** | `{port_idx 10, name USW-Pro-Max-24-PoE, portconf_id <UniFi Device>, setting_preference auto}`; 9 overrides as before |
| **Codifiable?** | Yes — `name` updated in `tofu/unifi/device_udm_pro_max.tf`. Done from the browser session: OpenBao was not running, so the shell path was unavailable. |

### Alarm Manager audit (read-only) — 2026-09-14

Read `Network → Alarm Manager` plus the UniFi OS endpoints the page calls (`/api/v2/alarms/network`, `/api/v2/alarms/profiles`, `/api/v2/alarms/network/manifest`; the Network-app `/v2/api/alarm-manager/scope/*` calls only list scope candidates). No writes. 17 rules, all defaults created 2026-09-05 at first boot, Notify → every admin, Always, admin preference push only; zero profiles. Provider has no alarm resource, so the rule set is documented as `FIXME(unifi)` in `system/alarms.tf`.

### Console page audit (read-only) and admin list

Read `Control Plane → Console` in the UI plus `/get/setting` (`mgmt`, `lcm`, `locale`, `country`, `ntp`, `super_mail`, `super_mgmt`) and `/api/stat/admin`. No writes. Result: `mgmt` and `lcm` blocks added to `unifi_setting.default`; every other item on the page is UniFi OS-side or a `super_*` setting and is listed as `FIXME(unifi)` in `system/settings.tf`; the two admin accounts are documented in `system/admins.tf` (no provider resource). Also listed the fixed-IP reservations without a name for the user (six of eight, all on Private Servers).

### Disabled ports renamed "… (Disabled)"

| | |
|---|---|
| **Endpoint** | `PUT /api/s/default/rest/device/<id>` with the full `port_overrides` array per device (read-modify-write), only `name` changed on overrides with `forward: disabled` |
| **Read-back** | UDM ports 2–8 → `Port N (Disabled)`; Pro Max 9–11 → `Port N (Disabled)`; Aggregation 2–7 → `SFP+ N (Disabled)` (first pass wrote `Port N (Disabled)` there, corrected in a second PUT to keep the original base name); override counts unchanged (9 / 25 / 8) |
| **Codifiable?** | Yes — `name` updated in the 16 disabled `port_override` blocks across `devices/*.tf`. |

### Auto speedtest enabled

| | |
|---|---|
| **Endpoint** | `POST /api/s/default/set/setting/auto_speedtest` `{enabled: true, cron_expr: "0 4 * * *"}` — the key did not exist before |
| **Read-back** | `{key auto_speedtest, enabled true, cron_expr "0 4 * * *"}` |
| **Codifiable?** | Already was — `unifi_setting.default.auto_speedtest` in `system/settings.tf` now matches live instead of being code-ahead-of-reality. |

### Fixed-IP clients named

| | |
|---|---|
| **Endpoint** | `PUT /api/s/default/rest/user/<id>` with `{name}` for the six unnamed reservations (names chosen by the user; the three VMs reuse their reported hostnames) |
| **Read-back** | all eight reservations now named; `fixed_ip`/`use_fixedip`/network binding unchanged: `Servacho-Gosho` .5.10, `JetKVM-Servacho-Gosho` .5.20, `JetKVM-Michelangelo` .5.23, `fmicodes-master-node` .5.200, `fmicodes-worker-node-1` .5.201, `hackjamhub-intercom` .5.215 |
| **Codifiable?** | Yes — `name` added to each block in `system/clients.tf` (still attribute-exact, see the #428 note there); the two JetKVM resources renamed after their hosts. |

### BPDU Guard enabled on the three host-facing port profiles

| | |
|---|---|
| **Where** | Settings → Overview → Port Profiles → *Host Device*, *Private Server*, *IoT Device* → Services → BPDU Guard |
| **Endpoint** | `PUT /api/s/default/rest/portconf/<id>` × 3, read-modify-write of the full profile with `stp_bpdu_guard_enabled: true` |
| **Before** | `false` on all five profiles |
| **After** | **`true`** on Host Device, Private Server, IoT Device; `false` on UniFi Device (deliberately — inter-switch/AP links carry BPDUs) and Public Server (no ports assigned, left as is) |
| **Codifiable?** | **No.** `unifi_port_profile` has no `stp_bpdu_guard_enabled`; recorded as `FIXME(unifi-ui-only)` in `core/port_profiles.tf`. |

Recommended and authorised in conversation: every port on these profiles is an end host, so a BPDU arriving means a rogue switch or a bridging host, and the guard err-disables the port rather than letting STP renegotiate around it. This also restores the protection Aggregation port 1 had under its old inline override. Read-back verified all other profile fields unchanged.

### Fixed-IP clients and device `config_network` — read-only, code aligned

`GET /rest/user` (fixed IPs) and `GET /stat/device` (`config_network`). Eight reservations live; `system/clients.tf` rewritten to match them attribute-for-attribute. All four managed devices report exactly the static management addresses the code declares, so the `config_network` blocks are no-op, not a failure — their FIXME text was corrected. No writes.

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
