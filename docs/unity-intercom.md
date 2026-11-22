# Unity Intercom on intercom.qo.ax

Unity Intercom Server runs on `mac4o-mini`, a Mac mini in Public Servers (VLAN 4, the `Dmz` zone) on USW Pro Max port 19 (*Public Server* profile), and is public as `intercom.qo.ax:20101`. Phones and PCs connect to it with the Unity Intercom client; no audio gear is wired to it yet.

| Piece | Where | Managed by |
|---|---|---|
| Fixed IP `192.168.4.24` for `1c:f6:4c:47:5b:c6` | `unifi_client.mac4o_mini`, `tofu/unifi/clients.tf` | tofu (set in the UI first, `docs/unifi-browser-changes.md`) |
| UDP 20101 on both WANs → `192.168.4.24:20101` | `unifi_port_forward.unity_intercom`, `tofu/unifi/port_forwards.tf` | tofu |
| TCP 20110 on all WANs → `192.168.4.24:20110`, TSL 3.1 tally (below) | `unifi_port_forward.unity_intercom_tally`, `tofu/unifi/port_forwards.tf` | tofu (made in the UI first, `docs/unifi-browser-changes.md`) |
| `intercom.qo.ax` A, DNS only, TTL 60, comment "Unity Intercom on mac4o-mini; UDP 20101, TCP 20110 tally forwarded by servacho. [follows-wan]" | Cloudflare, zone `qo.ax` (Quackstack account) | [qoax-infrastructure](https://github.com/qoax-community/qoax-infrastructure) (`tofu/dns/follows_wan.tf`, `docs/dns.md`), which ignores its address; the address is `wan-dns`'s |
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

The server shows a video mixer's tally on the clients: red for Program, green for Preview. Each user has a **Tally ID** (Tally/GPIO tab, user table), or N/A for no tally. For ATEM, TriCaster and vMix the server connects out to the mixer's IP address, which a mixer behind a venue's NAT does not allow. So tally from a venue comes in as TSL 3.1 instead: a converter on the venue's network reads the mixer and connects out to `intercom.qo.ax:20110`. The venue needs no forward, and the record follows the WAN as for the clients.

TSL 3.1 has no authentication, so anyone who reaches TCP 20110 can light the clients' tally. The forward has no source limit, because venue addresses are not known in advance. The worst case is a wrong tally light, and only while the server's tally interface is TSL 3.1.

### The converter: Tally Arbiter on the vMix PC

[Tally Arbiter](https://github.com/josephdadams/TallyArbiter) (tested with 3.3.0) runs on the vMix PC at the venue, with its web UI on `http://127.0.0.1:4455` and its config in `%APPDATA%\TallyArbiter\config.json`. First used on 2026-11-22.

| Setting | Value |
|---|---|
| Source | type VMix, IP `127.0.0.1` (vMix's TCP API, port 8099) |
| Devices | one per camera, with a TSL address (below) and one device source: VMix, address = the vMix input number |
| TSL client (Settings → Listeners) | `intercom.qo.ax`, port 20110, transport **TCP**, protocol TSL 3.1, Tally 1 = PVW, Tally 2 = PGM |
| 1-Second Updates | on, so a client that missed a change catches up within a second |

Unity shows a TSL address one higher than the address sent, and Tally Arbiter never sends address 0. So camera N gets **TSL address 99 + N** in Tally Arbiter and **Tally ID 100 + N** in Unity:

| Camera | vMix input (2026-11-22) | Tally Arbiter TSL address | Unity Tally ID |
|---|---|---|---|
| CAM_MAIN | 14 | 100 | 101 |
| CAM_SECOND | 15 | 101 | 102 |
| CAM_THIRD | 18 | 102 | 103 |

vMix's tally also counts an input shown as a layer of another input, so a camera inside a layout in Program shows red. The device sources follow vMix input **numbers**, not names, because that is all the vMix source reads: deleting or moving an input before a camera changes its number, and the device source must follow.

To check it, the Tally/GPIO tab on the server shows **Tally Status** (green while a TSL client is connected) and indicators 1 to 128 (grey off, green Preview, red Program).

### Tally Arbiter's limits

- **It connects once.** The TCP client does not retry after a refused or closed connection. After the server restarts, the WAN fails over or the connection drops, Tally Arbiter stays disconnected until its TSL client is saved again (Edit → Save Changes, which reconnects after 5 seconds) or Tally Arbiter restarts. On Windows, `Get-NetTCPConnection -RemotePort 20110 -State Established` shows whether it is connected.
- **The server keeps one TSL client.** A second connection to TCP 20110 drops the first, so anything else that sends TSL takes Tally Arbiter off until it is saved again.
- **Saving the TSL client writes a config without it.** Tally Arbiter writes `config.json` while the client is stopped for its 5-second restart. The client then runs but is gone after the next restart of Tally Arbiter. Any later change saves the file again; turning 1-Second Updates off and on is the shortest one.
- **A dropped address stays lit.** The server keeps the last state of a TSL address that nobody sends any more, for example after a camera's address changes. To clear it, send that address an 18-byte TSL 3.1 packet with every tally bit off: byte 0 = `0x80` + address, byte 1 = `0xC0`, then 16 bytes of text. Then save Tally Arbiter's TSL client again, because the extra connection drops it.

## Administration

Unity Server is a menu-bar app with no web UI or API: users, passwords, channels and groups are changed in its window, over Screen Sharing (`vnc://192.168.4.24`) from Main, Teleport or WireGuard. Public Servers has no mDNS reflection, so connect by address, not by Bonjour name; the Dmz zone lets Internal reach the Mac but not the other way round. It runs only while a user is logged in on the Mac, so the Mac needs automatic login, Start at Login on in Unity Server, and no sleep (`sudo pmset -a sleep 0 autorestart 1`).

## Program audio from a venue

The venue's vMix Master reaches the crew as a Unity program feed. Unity Server takes a program feed only from an audio input of the Mac (Audio Feeds → **Source**). So the audio goes to the Mac first, through Qoax's SRT relay ([qoax-broadcast.md in qoax-infrastructure](https://github.com/qoax-community/qoax-infrastructure/blob/main/docs/qoax-broadcast.md)):

1. vMix publishes an SRT output to the relay's feed `vmix1`, at `srt.qo.ax:8890`. The output's Audio Channels setting is **Master**.
2. The Mac reads `vmix1` as a reader at home, from `192.168.12.23:8890`. It plays the audio, mono, into BlackHole 2ch, a virtual audio device.
3. Unity Server uses BlackHole 2ch as its Input Device. Audio Feeds → program feed 1 has Source = Audio Input 1, and the crew's users can select that feed in their clients.

| Piece | Where | Managed by |
|---|---|---|
| UDP 8890 from `192.168.4.24` to `192.168.12.23` | `unifi_firewall_policy.allow_intercom_to_srt_relay`, `tofu/unifi/firewall.tf` | tofu |
| Feed `vmix1`, its reader and passphrases | qoax-infrastructure (`nixos/hosts/qoax-broadcast-srt/feeds.json`), URLs in OpenBao | qoax-infrastructure |
| The reader on the Mac: LaunchAgent `ax.qo.unity-program-feed` | `scripts/unity-program-feed.zsh`, run on the Mac | by hand (below) |
| Input Device, program feed 1, the users' allowed feeds | Unity Server window | by hand |
| The SRT output | vMix, Settings → Outputs/NDI/OMT/SRT | by hand, at the venue |

Both hosts are in `Dmz`, whose predefined policies block traffic between its own networks, so the policy opens only this flow. Reading through `srt.qo.ax` instead would need the gateway to loop UDP back to its own WAN address.

### The reader on the Mac

To install it, copy `scripts/unity-program-feed.zsh` to the Mac and run `zsh unity-program-feed.zsh` in Terminal, as the user that runs Unity Server. It installs Homebrew's `ffmpeg`, `srt` and `blackhole-2ch`. Then it asks for `vmix1_read_url_home`. The Mac cannot reach OpenBao, because the Dmz zone blocks it, so get the URL on another computer and paste it at the hidden prompt.

The script writes `run.sh` and the LaunchAgent. These design points come from the first setup on 2026-11-22:

- **Two programs.** Homebrew's `ffmpeg` has no libsrt. `srt-live-transmit`, from Homebrew's `srt`, receives the feed and sends MPEG-TS to `ffmpeg` through a pipe.
- **The device by name.** The `audiotoolbox` output of `ffmpeg` takes a device index, and the index changes when devices change. `audiotoolbox` is an output only, so `run.sh` lists the devices through an output at each start and finds BlackHole 2ch by its name.
- **A short probe.** With its default probe, `ffmpeg` held about 5 s of the live pipe, and that backlog stayed as delay. `-probesize 32768 -analyzeduration 0` brought it down to 0.3 s.
- **Restarts.** launchd starts `run.sh` again 10 s after it stops, for example while vMix does not publish.
- **The URL.** It is in `~/Library/Application Support/unity-program-feed/read-url`, mode 0600. `srt-live-transmit` gets it as an argument, so another local user can read it with `ps`. The URL only lets a reader play `vmix1`.

CoreAudio loads BlackHole only after `sudo killall coreaudiod` or a restart of the Mac. The first command interrupts Unity Server's audio for a moment.

To check the reader, run these on the Mac:

```sh
launchctl print gui/$(id -u)/ax.qo.unity-program-feed | grep -E 'state|last exit'
tail ~/Library/Logs/unity-program-feed.log
```

`state = running` and an empty log are correct. On 2026-11-22 the feed was AAC LC, 48 kHz, stereo, from vMix 29. After the user unmuted vMix Master, the feed measured a mean of -20 dB, and the Android client played it. A feed at -91 dB is digital silence: examine the Master bus in vMix before the Mac.

## Known gaps

- **The plane.** Failover depends on Qoax's management plane and its OpenBao being up ([wan-dns.md](wan-dns.md)); while they are not, the record keeps whichever address it last had.
- **Audio gear (planned for March 2027).** The Audio I/O licence is held (confirmed 2026-11-22, and used for the program audio above); Unity Connect (UDP 20102) only if the gear is at another site.
