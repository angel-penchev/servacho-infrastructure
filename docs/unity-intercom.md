# Unity Intercom on intercom.qo.ax

Unity Intercom Server runs on `mac4o-mini`, a Mac mini in Public Servers (VLAN 4, the `Dmz` zone) on USW Pro Max port 19 (*Public Server* profile), and is public as `intercom.qo.ax:20101`. Phones and PCs connect to it with the Unity Intercom client; no audio gear is wired to it yet.

| Piece | Where | Managed by |
|---|---|---|
| Fixed IP `192.168.4.24` for `1c:f6:4c:47:5b:c6` | `unifi_client.mac4o_mini`, `tofu/unifi/clients.tf` | tofu (set in the UI first, `docs/unifi-browser-changes.md`) |
| UDP 20101 on both WANs → `192.168.4.24:20101` | `unifi_port_forward.unity_intercom`, `tofu/unifi/port_forwards.tf` | tofu |
| TCP 20110 on all WANs → `192.168.4.24:20110`, TSL 3.1 tally (below) | `unifi_port_forward.unity_intercom_tally`, `tofu/unifi/port_forwards.tf` | tofu (made in the UI first, `docs/unifi-browser-changes.md`) |
| `intercom.qo.ax` A, DNS only, TTL 60, comment "Unity Intercom on mac4o-mini; UDP 20101 forwarded by servacho-infrastructure. [follows-wan]" | Cloudflare, zone `qo.ax` (Quackstack account) | [qoax-infrastructure](https://github.com/qoax-community/qoax-infrastructure) (`tofu/dns/follows_wan.tf`, `docs/dns.md`), which ignores its address; the address is `wan-dns`'s |
| `wan-dns`: the record's address follows the active WAN | `nixos/hosts/qoax-community-management-plane/wan-dns.nix` ([wan-dns.md](wan-dns.md)) | NixOS on Qoax's management plane (`192.168.10.15`), beside the repository that manages the zone |

The record must stay DNS only: Cloudflare's proxy carries HTTP(S), not UDP. Change its TTL or comment in qoax-infrastructure, not the dashboard.

## WAN failover

WAN1 (`46.10.181.183`) is primary and WAN2 (`87.126.144.74`) failover-only. The forward is on both, and `wan-dns` on Qoax's management plane moves the record to whichever is active ([wan-dns.md](wan-dns.md)): the record carries `[follows-wan]` in its comment, from qoax-infrastructure.

After WAN1 fails, clients reach the intercom again within about three minutes: the gateway's failover, the next minute's run, and the 60 s TTL. Calls in progress drop and clients reconnect. It moves back the same way when WAN1 returns.

## Server settings the network depends on

- **Pro → encryption on, "Leave TCP Port Open" off.** The server then listens on UDP 20101 only (on 2026-10-14 TCP 20101 was refused and UDP 20101 answered like an open port), which is why the forward is UDP alone. Opening the TCP port again means `protocol = "tcp_udp"`.
- **General → Network Port 20101.** A different port means changing both sides of the forward.
- **Tally/GPIO → Tally Interface Type TSL 3.1, Tally Port 20110.** A different port means changing both sides of `unity_intercom_tally`. The tally fields need the Unity Intercom Tally licence or trial mode.

## Tally from a venue

The server shows a video mixer's tally on the clients: red for Program, green for Preview. Each user's **Tally ID** in the server's user settings is the mixer input of the camera that user operates, or N/A for no tally. For ATEM, TriCaster and vMix the server connects out to the mixer's IP address, which a mixer behind a venue's NAT does not allow. So tally from a venue comes in as TSL 3.1 instead: a converter on the venue's network (for example Tally Arbiter) reads the mixer and connects out to `intercom.qo.ax:20110`. The venue needs no forward, and the record follows the WAN as for the clients.

TSL 3.1 has no authentication, so anyone who reaches TCP 20110 can light the clients' tally. The forward has no source limit, because venue addresses are not known in advance. The worst case is a wrong tally light, and only while the server's tally interface is TSL 3.1.

## Administration

Unity Server is a menu-bar app with no web UI or API: users, passwords, channels and groups are changed in its window, over Screen Sharing (`vnc://192.168.4.24`) from Main, Teleport or WireGuard. Public Servers has no mDNS reflection, so connect by address, not by Bonjour name; the Dmz zone lets Internal reach the Mac but not the other way round. It runs only while a user is logged in on the Mac, so the Mac needs automatic login, Start at Login on in Unity Server, and no sleep (`sudo pmset -a sleep 0 autorestart 1`).

## Program audio from a venue

The venue's vMix Master plays into the Teams Support Crew channel, so the crew hears the show. Unity mixes audio into a channel only from the Mac's own Input Device (Channels → **Input Number**), so the audio travels to the Mac first, through Qoax's SRT relay ([qoax-broadcast.md in qoax-infrastructure](https://github.com/qoax-community/qoax-infrastructure/blob/main/docs/qoax-broadcast.md)):

1. vMix publishes an SRT output to the relay's feed `vmix1`, at `srt.qo.ax:8890`.
2. The Mac reads `vmix1` as a reader at home, from `192.168.12.23:8890`, and plays its audio into a virtual audio device.
3. Unity Server takes that device as its Input Device, and the Teams Support Crew channel takes its input.

| Piece | Where | Managed by |
|---|---|---|
| UDP 8890 from `192.168.4.24` to `192.168.12.23` | `unifi_firewall_policy.allow_intercom_to_srt_relay`, `tofu/unifi/firewall.tf` | tofu |
| Feed `vmix1`, its reader and passphrases | qoax-infrastructure (`nixos/hosts/qoax-broadcast-srt/feeds.json`), URLs in OpenBao | qoax-infrastructure |

Both hosts are in `Dmz`, whose predefined policies block traffic between its own networks, so the policy opens only this flow. Reading through `srt.qo.ax` instead would need the gateway to loop UDP back to its own WAN address.

## Known gaps

- **The plane.** Failover depends on Qoax's management plane and its OpenBao being up ([wan-dns.md](wan-dns.md)); while they are not, the record keeps whichever address it last had.
- **Audio gear (planned for March 2027).** The Audio I/O licence is held (confirmed 2026-11-22, and used for the program audio above); Unity Connect (UDP 20102) only if the gear is at another site.
