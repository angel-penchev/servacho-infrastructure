# Unity Intercom on intercom.qo.ax

Unity Intercom Server runs on `mac4o-mini`, a Mac mini in Main (VLAN 2) on USW Pro Max port 19, and is public as `intercom.qo.ax:20101`. Phones and PCs connect to it with the Unity Intercom client; no audio gear is wired to it yet.

| Piece | Where | Managed by |
|---|---|---|
| Fixed IP `192.168.2.158` for `1c:f6:4c:47:5b:c6` | `unifi_client.mac4o_mini`, `tofu/unifi/clients.tf` | tofu (set in the UI first, `docs/unifi-browser-changes.md`) |
| UDP 20101 on both WANs → `192.168.2.158:20101` | `unifi_port_forward.unity_intercom`, `tofu/unifi/port_forwards.tf` | tofu |
| `intercom.qo.ax` A, DNS only, TTL 60, comment "Unity Intercom on mac4o-mini; UDP 20101 forwarded by servacho-infrastructure." | Cloudflare, zone `qo.ax` (Quackstack account) | made **by hand** (no Cloudflare provider in this repo); its address kept current by `intercom-dns` |
| `intercom-dns`: the record's address follows the active WAN | `nixos/hosts/servacho-managment-plane/intercom-dns.nix` | NixOS on the root management plane |

The record must stay DNS only: Cloudflare's proxy carries HTTP(S), not UDP.

## WAN failover

WAN1 (`46.10.181.183`) is primary and WAN2 (`87.126.144.74`) failover-only. The forward is on both, and `intercom-dns` on the root management plane moves the record between them: every minute it asks Cloudflare which address the plane's traffic comes from (the active WAN's, since the plane goes out through it like everything else), and when the record differs it PATCHes the record's address. A PATCH leaves the TTL and comment alone; a PUT, which is what `cloudflare-dyndns` sends, would reset them. The same run also catches WAN1's own address changing.

After WAN1 fails, clients reach the intercom again within about three minutes: the gateway's failover, the next minute's run, and the 60 s TTL. Calls in progress drop and clients reconnect. It moves back the same way when WAN1 returns.

The service needs a Cloudflare API token with **Zone → DNS → Edit** on `qo.ax` alone, placed by hand on the plane:

```bash
sudo install -d -m 0700 /var/lib/intercom-dns
sudo install -m 0400 /dev/stdin /var/lib/intercom-dns/.token   # paste the token, then Ctrl-D
```

Until the file is there the unit is skipped, not failed. `journalctl -u intercom-dns` logs each change as `intercom.qo.ax: <old> -> <new>`; a run with nothing to do logs nothing.

## Server settings the network depends on

- **Pro → encryption on, "Leave TCP Port Open" off.** The server then listens on UDP 20101 only (on 2026-10-14 TCP 20101 was refused and UDP 20101 answered like an open port), which is why the forward is UDP alone. Opening the TCP port again means `protocol = "tcp_udp"`.
- **General → Network Port 20101.** A different port means changing both sides of the forward.

## Administration

Unity Server is a menu-bar app with no web UI or API: users, passwords, channels and groups are changed in its window, over Screen Sharing (`vnc://192.168.2.158`) from Teleport or WireGuard. It runs only while a user is logged in on the Mac, so the Mac needs automatic login, Start at Login on in Unity Server, and no sleep (`sudo pmset -a sleep 0 autorestart 1`).

## Known gaps

- **The plane.** Failover depends on the root management plane being up; while it is down the record keeps whichever address it last had.
- **Zone.** The forward lands in Main, the trusted Internal zone. Public Servers (VLAN 4, Dmz) exists for this and is unused; moving the Mac there means a new fixed IP and editing both tofu resources.
- **Audio gear (planned for March 2027).** Needs the Audio I/O licence; Unity Connect (UDP 20102) only if the gear is at another site.
