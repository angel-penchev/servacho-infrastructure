# Unity Intercom on intercom.qo.ax

Unity Intercom Server runs on `mac4o-mini`, a Mac mini in Main (VLAN 2) on USW Pro Max port 19, and is public as `intercom.qo.ax:20101`. Phones and PCs connect to it with the Unity Intercom client; no audio gear is wired to it yet.

| Piece | Where | Managed by |
|---|---|---|
| Fixed IP `192.168.2.158` for `1c:f6:4c:47:5b:c6` | `unifi_client.mac4o_mini`, `tofu/unifi/clients.tf` | tofu (set in the UI first, `docs/unifi-browser-changes.md`) |
| UDP 20101 on WAN1 → `192.168.2.158:20101` | `unifi_port_forward.unity_intercom`, `tofu/unifi/port_forwards.tf` | tofu |
| `intercom.qo.ax` A `46.10.181.183`, DNS only, TTL Auto | Cloudflare, zone `qo.ax` (Quackstack account) | **by hand**: no Cloudflare provider in this repo |

The record must stay DNS only: Cloudflare's proxy carries HTTP(S), not UDP.

## Server settings the network depends on

- **Pro → encryption on, "Leave TCP Port Open" off.** The server then listens on UDP 20101 only (on 2026-10-14 TCP 20101 was refused and UDP 20101 answered like an open port), which is why the forward is UDP alone. Opening the TCP port again means `protocol = "tcp_udp"`.
- **General → Network Port 20101.** A different port means changing both sides of the forward.

## Administration

Unity Server is a menu-bar app with no web UI or API: users, passwords, channels and groups are changed in its window, over Screen Sharing (`vnc://192.168.2.158`) from Teleport or WireGuard. It runs only while a user is logged in on the Mac, so the Mac needs automatic login, Start at Login on in Unity Server, and no sleep (`sudo pmset -a sleep 0 autorestart 1`).

## Known gaps

- **WAN failover.** The forward is on WAN1 and the record points at its address. While the gateway runs on WAN2 (`87.126.144.74`) the intercom is unreachable from outside.
- **Address changes.** Nothing updates the record if WAN1's address changes.
- **Zone.** The forward lands in Main, the trusted Internal zone. Public Servers (VLAN 4, Dmz) exists for this and is unused; moving the Mac there means a new fixed IP and editing both tofu resources.
- **Audio gear (planned for March 2027).** Needs the Audio I/O licence; Unity Connect (UDP 20102) only if the gear is at another site.
