# Runbook: move UniFi device management to VLAN 99

**Decided:** 2026-09-13 · **Status:** Phase 0 done (2026-09-13); Phases 1–4 pending
**Goal:** infrastructure management leaves the untagged Default LAN (VLAN 1, `192.168.1.0/24`) for a tagged network **UniFi Devices, VLAN 99, `192.168.99.0/24`**. VLAN 1 becomes an empty parking lot. Nothing else moves: Main/Guest/Public/Private/IoT/Qoax/FMI keep their IDs and subnets, so the VLAN-ID-equals-third-octet convention stays intact for every network that has clients.

Every step is **UI first, then read back, then mirror in code** — the same discipline as the rest of `docs/unifi-browser-changes.md`. `tofu apply` is not part of this; the code follows live.

---

## Why this order

A device's management traffic is the one thing you cannot fix from the controller once it breaks — the controller *is* the other end of it. So:

- **Leaves before trunks.** Re-home the APs first (they hang off the Pro Max), then the Pro Max, then the Aggregation. A mistake on a leaf takes one device out; a mistake on a trunk takes everything behind it.
- **DHCP before static.** Each device first moves with DHCP on the new network. Only when it is adopted and stable on VLAN 99 does it get its static `.99.x`. A wrong static + wrong VLAN in one apply is how you end up with a factory reset.
- **Tagged before native.** Devices move to VLAN 99 as a *tagged* management VLAN over the existing trunks (the UniFi Device profile allows all VLANs, so 99 is carried the moment the network exists). Only after all five are on 99 does the trunk's *native* network change — and that step is optional.

Between every step: read back via the API (`/stat/device`: `mgmt_network_id`, `ip`, `state = 1`), and confirm from a client that Wi-Fi still works.

## Safety net — have this before Phase 2

- A laptop you can plug into a **UniFi Device** port (Pro Max 23/24 are the AP uplinks; the UDM's LAN ports 2–8 are *disabled* — re-enable one in the UI if you want a console port on the gateway itself). It will land on the Default LAN and reach the controller at `192.168.1.1`.
- The UDM's local console (UniFi OS at `https://192.168.1.1`) is reachable from Main regardless of what the switches do, because routing between Main and the Default LAN is gateway-internal.
- Know where the physical reset pinholes are on both switches. Worst case is a re-adoption, not data loss.
- Do it when a few minutes without Wi-Fi is acceptable.

## Address plan

| Device | Today (VLAN 1) | After (VLAN 99) |
|---|---|---|
| UDM StKr | `192.168.1.1` (gateway on Default) | also `192.168.99.1` (gateway on UniFi Devices) — the UDM does not "move"; it gains an interface |
| USW Pro Max 24 PoE | `.1.2` static | `.99.2` static |
| USW Aggregation | `.1.3` static | `.99.3` static |
| Living Room U7-Pro | `.1.4` static | `.99.4` static |
| Bedroom U7-Pro | `.1.5` static | `.99.5` static |
| DHCP pool | `.1.6–.1.254` | `.99.6–.99.254` |

Nothing else has an address on VLAN 1 today (the two JetKVMs were moved to Private Servers on 2026-09-13). `192.168.99.0/24` collides with nothing: Teleport is `.7.0/24`, WireGuard is planned for `.8.0/24`.

---

## Phase 0 — create the network *(non-disruptive)* — ✅ done 2026-09-13

Done via the API from the logged-in session; the untagged network was named **`Default (Untagged)`** (user's choice, to make its role obvious in every dropdown). Read back: VLAN 99 `UniFi Devices`, `192.168.99.1/24`, DHCP `.6–.254`, lease 86400, mDNS off, Internal zone (same `firewall_zone_id` as Main), `is_nat true`, `setting_preference manual`. Code mirrored in `core/networks.tf` (`unifi_network.default` renamed, `unifi_network.unifi_devices` added) and `core/outputs.tf`.

UI: Settings → Networks → Create New.

| Field | Value |
|---|---|
| Name | `UniFi Devices` (the old untagged network became `Default (Untagged)`) |
| Zone | Internal (same as today's UniFi Devices network; inter-VLAN routing to the Default LAN stays open so devices can still reach `192.168.1.1:8080/inform` during the move) |
| VLAN ID | 99 |
| Gateway IP/Subnet | `192.168.99.1/24` |
| DHCP | Server, `192.168.99.6–192.168.99.254`, lease 86400 (the site default) |
| IPv6 | none · mDNS off (the site-wide proxy is scoped to Main + IoT) · isolation off |

**Naming note.** Two networks cannot share a name. Do this in Phase 0 in this order: rename the current Default network from `UniFi Devices` to **`Default`**, *then* create the VLAN 99 network as `UniFi Devices`. Renaming the Default network changes nothing functionally.

Read back: `/rest/networkconf` shows `Default` (untagged, `.1.1/24`) and `UniFi Devices` (`vlan 99`, `.99.1/24`, `dhcpd_enabled true`). Check `firewall_zone_id` of the new network equals the Internal zone's.

Mirror in code: `unifi_network.default` → `name = "Default"`; new `unifi_network.unifi_devices` (vlan 99); new output `network_unifi_devices_id`; note in `TODO(vlan1)` → decision recorded. **Commit.**

## Phase 1 — Living Room U7-Pro, then Bedroom U7-Pro

Per AP, UI: Devices → *AP* → Settings → IP Settings.

1. Tick **Network Override**, choose **UniFi Devices** (VLAN 99). Set IP Configuration to **DHCP**. Apply.
2. Wait. The AP re-provisions (30–90 s, Wi-Fi on that AP drops). It should come back with a `.99.x` DHCP lease and `state 1`. If it stays offline > 5 min: it is still on its old static `.1.4` but tagging 99 — power-cycle it via PoE (Port Manager → port 23 → PoE off/on). If still nothing, see *Rollback*.
3. Once adopted on 99: same panel, IP Configuration → **Static** `.99.4` / `255.255.255.0` / gw `192.168.99.1` / DNS `192.168.99.1`. Apply. Short blip, back within a minute.
4. Read back: `mgmt_network_id` = UniFi Devices, `ip` = `.99.4`, `config_network.type static`.
5. Repeat for Bedroom (`.99.5`, port 24).

Mirror in code after both: `devices/u7_pro_*.tf` → `mgmt_network_id = var.network_unifi_devices_id`, `config_network.ip/gateway/dns1` → `.99.x` / `.99.1`. **Commit.**

## Phase 2 — USW Pro Max 24 PoE

This is the first step that can take clients with it (every access port hangs off this switch; the APs do too). Wi-Fi will drop for a minute while the switch re-provisions.

1. Network Override → UniFi Devices, DHCP. Apply. Wait for `state 1` and a `.99.x` lease. The APs behind it should come back on their own (they were already on 99).
2. Static `.99.2`. Apply. Read back.
3. Confirm: all three downstream devices `state 1`; a wired client on Host Device still gets Main; a Wi-Fi client still works.

Mirror in code. **Commit.**

## Phase 3 — USW Aggregation

Same two steps, `.99.3`. Servacho-Gosho (port 1, Private Servers) is unaffected by the switch's own management VLAN, but verify `192.168.5.10` still answers afterwards.

Mirror in code. **Commit.**

## Phase 4 — retire the Default LAN *(optional, recommended)*

With all four devices on 99:

1. **UniFi Device port profile → Native VLAN/Network → `UniFi Devices` (99).** All trunks now carry management *untagged* on 99 instead of tagged; the devices' `mgmt_network_id` already equals the native, so the switches switch to untagged management in place. This is the one step where all four devices reconfigure at once — expect a blip on everything, and a re-adoption if it goes wrong. Do it last, on a quiet evening, with the laptop plugged in.
   - Benefit: a factory-reset device plugged into any UniFi Device port lands on 99 with DHCP and adopts normally, so the Default LAN no longer needs to serve adoption.
2. **Default network → DHCP off.** Anything that ever lands untagged on VLAN 1 now gets no address. Keep the network (it cannot be deleted: `attr_no_delete`).
3. Read back; mirror (`unifi_port_profile.unifi_devices.native_networkconf_id`, `unifi_network.default.dhcp_server.enabled = false`). **Commit.**

If Phase 4 is skipped, leave Default DHCP **on** — it is what a freshly reset device needs to be adopted.

## Rollback

A device that lost the controller after step 1 of its phase is still reachable on its **old** static address (`.1.x`) via the Default LAN if — and only if — its management VLAN reverted. It usually will not have. Options, in order:

1. Wait 5 minutes. Provisioning is slower than it looks.
2. PoE-cycle (APs) or power-cycle (switches). A UniFi device that cannot reach its controller for a while retries its last-known-good config.
3. Plug the laptop into a UniFi Device port, open `https://192.168.1.1`, and check whether the device shows *Adopting* / *Disconnected*. If Disconnected: Settings → toggle Network Override off → Apply. The controller pushes it on the next inform.
4. Factory reset the device (pinhole 10 s) and re-adopt. It comes back on the Default LAN via DHCP; its port overrides live on the controller and re-apply on adoption. The only thing lost is the ~2 minutes.

## Tofu notes

- `unifi_device.mgmt_network_id` and `config_network` are both declared; `mgmt_network_id` *is* in the v0.55.0 minimal update PUT, `config_network` is not. Since code mirrors live after each phase, neither produces a diff.
- Nothing in `security/`, `wireless/`, `system/` references the Default network's *ID* except the Hotspot/Dmz zones (which do not touch it) — verified by grep. The 802.1X fallback VLAN is Guest, unaffected.
- The `Internal` firewall zone is not managed in code; the new network joins it by default. If you later want management in its own zone, that is a `unifi_firewall_zone` resource plus policies — separate decision.
