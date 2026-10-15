# wan-dns: DNS records that follow the active WAN

The home has two internet lines: WAN1 (`46.10.181.183`), the primary, and
WAN2 (`87.126.144.74`), used only while WAN1 is down. A DNS record that points
at the home has to follow whichever one is active. `wan-dns` does that, on
Qoax Community's management plane (`192.168.10.15`), where the zones are
managed (qoax-infrastructure, its `docs/dns.md`).

| Piece | Where |
|---|---|
| The job, every minute | `nixos/hosts/qoax-community-management-plane/wan-dns.nix`, in this repository |
| Which records: every A record whose comment carries `[follows-wan]` | qoax-infrastructure's `tofu/dns/follows_wan.tf`, which writes the marker and ignores the records' address |
| The zones to search | The plane's OpenBao, `secret/cloudflare-zones`, written by qoax-infrastructure's apply |
| The Cloudflare token | The plane's OpenBao, `secret/cloudflare`: the one qoax-infrastructure's OpenTofu uses, DNS Edit on the account's zones |
| What `wan-dns` may read | The OpenBao policy `wan-dns` (qoax-infrastructure's `tofu/dns_module.tf`): those two secrets and nothing else |

## What a run does

1. If the plane's OpenBao is sealed, as it is after a reboot until
   `tenant-planes-unseal.yaml` unseals it (every 30 minutes), it does nothing.
2. It renews its own OpenBao token and reads the Cloudflare token and the
   zones.
3. It asks Cloudflare which address the plane reaches the internet from. The
   plane goes out through the active WAN like everything else on the network;
   no VLAN is pinned to a WAN.
4. In each zone, it PATCHes the address of every marked A record that differs.
   A PATCH leaves the TTL and comment alone; a PUT, which is what
   `cloudflare-dyndns` sends, would reset them.

After WAN1 fails, a record follows within about three minutes: the gateway's
failover, the next minute's run, and the record's TTL (60 s for
`intercom.qo.ax`). It moves back the same way, and the same run catches either
line's own address changing.

`journalctl -u wan-dns` logs each change as `<name>: <old> -> <new>`; a run with
nothing to do logs nothing.

## The OpenBao token

`wan-dns` reads OpenBao with a periodic token of the `wan-dns` policy, placed
by hand once, after qoax-infrastructure's apply has made the policy. Every run
renews it, so it lives as long as the job keeps running; a plane down for
longer than the period (30 days) needs a new one. Log in to the plane's
OpenBao with the root token kept in the root OpenBao at
`secret/management-planes/qoax-community`:

```bash
ssh root@192.168.10.15
export BAO_ADDR=http://127.0.0.1:8200
bao login
install -d -m 0700 /var/lib/wan-dns
bao token create -orphan -policy=wan-dns -period=720h -display-name=wan-dns -field=token |
  install -m 0400 /dev/stdin /var/lib/wan-dns/.bao-token
rm ~/.vault-token
```

Until the file is there, the unit is skipped, not failed.

## Known gaps

- **The plane.** While Qoax Community's management plane is down, or its
  OpenBao sealed, the records keep whichever address they last had.
- **IPv4 only.** Only A records follow; nothing points at the home over IPv6.
