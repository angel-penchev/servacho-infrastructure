# os-tues: the operating systems class's machine

`os-tues` is where TUES' operating systems class (11A, 2026/2027) writes and
runs its assembly and C. Every student has an account and logs in from
anywhere as `<student>@os-tues.qo.ax`. It runs NixOS, like every other host
here, so it is installed, deployed and changed by this repository. Students
install extra programs into their own accounts without root.

| Piece | Where | Managed by |
|---|---|---|
| VM 4031 on Public Servers (VLAN 4, the `Dmz` zone), `192.168.4.31`. It has 4 cores and 12 GiB, ballooning down to 4 GiB, plus a 64 GiB system disk and a 64 GiB disk for `/home` | `tofu/os_tues.tf`, with infrastructure-reusables' `nixos-vm` | tofu |
| The host: toolchain, accounts, per-login limits, SSH | `nixos/hosts/os-tues.nix` | tofu, deployed in place |
| The roster: each student's user name and initial password hash | The root OpenBao, `secret/os-tues/students` | by hand (below) |
| TCP 22 on both WANs → `192.168.4.31:22` | `unifi_port_forward.os_tues_ssh`, `tofu/unifi/port_forwards.tf` | tofu |
| `os-tues.qo.ax` A record: DNS only, TTL 60, `[follows-wan]` | Cloudflare, zone `qo.ax` | [qoax-infrastructure](https://github.com/qoax-community/qoax-infrastructure)'s `tofu/dns/follows_wan.tf`. The address belongs to `wan-dns` ([wan-dns.md](wan-dns.md)) |

The record must stay DNS only, because Cloudflare's proxy doesn't carry SSH.

## Accounts

- **User name:** the student's ELSYS address without `@elsys-bg.org`, for
  example `ivan.i.ivanov.2023`.
- **Initial password:** the student's middle name as sigma has it, written
  in Latin letters, followed by the last four digits of the phone number
  sigma has for them. `Иванов` and `0888 12 34 56` give `Ivanov3456`.
  - The Latin spelling follows Bulgaria's official transliteration, the
    one on ID cards: `й` → `y`, `ц` → `ts`, `щ` → `sht`, `ъ` → `a`,
    `ю` → `yu`, `я` → `ya`, and `-ия` at the end → `-ia`.
  - Only the first letter is a capital.
- **First login:** sshd asks for the initial password, then for it again as
  the "current" password, then twice for a new one. The connection then
  carries on into the shell.

`os-tues-students` (`nixos/hosts/os-tues.nix`) runs at boot and whenever the
apply hands the host a changed roster. It:

- creates an account for each new student on the roster. Each gets a private
  group, a `/home/<student>` only they can enter, and an initial password
  that has to be changed;
- never touches the password of an account that already exists;
- locks out students who are no longer on the roster, by expiring their
  accounts, and keeps their homes. A student put back on the roster can log
  in again.

`journalctl -u os-tues-students` on the host lists what each run did.

### Writing the roster

The roster is a map of user name to yescrypt hash. It lives in OpenBao
because this repository is public: the names are minors', and hashes of
passwords this guessable would leak the passwords themselves. Starting from a
`students.tsv` of `<user name><TAB><initial password>` lines:

```bash
while IFS=$'\t' read -r user password; do
  printf '%s\t%s\n' "$user" "$(mkpasswd -m yescrypt --stdin <<<"$password")"
done <students.tsv |
  jq -Rn '[inputs | split("\t") | {key: .[0], value: .[1]}] | from_entries' >students.json
shred -u students.tsv
```

Then, on the root plane, with the root token:

```bash
bao kv put -mount=secret os-tues/students @students.json
```

Every plan reads the roster, so any apply after a change hands it over: the
next merge to `main`, or `OpenTofu Apply` run by hand on `main`. To add one
student:

```bash
bao kv patch -mount=secret os-tues/students "new.student.2023=$(mkpasswd -m yescrypt)"
```

To remove one, write the map back without them:

```bash
bao kv get -mount=secret -format=json os-tues/students |
  jq '.data.data | del(.["old.student.2023"])' |
  bao kv put -mount=secret os-tues/students -
```

### A forgotten password

From the home network or WireGuard (root logs in with a key, from
`192.168.0.0/16` only):

```bash
ssh root@192.168.4.31
passwd <student>
chage --lastday 0 <student>
```

Tell the student the password you set; they replace it at their next login.

## What students get

- **The toolchain the notes use:**
  - `nasm`, binutils (`ld`, `objdump`, `readelf`, `nm`), `make`
  - `gcc`, `gdb`, `valgrind`, `strace`, `ltrace`
  - `nano`, `vim`, `nvim`, and `gedit` over `ssh -X`
  - man pages for sections 2 and 3, POSIX's (`3p`) and `man -k`. `man -k`
    answers once `mandb.service` has indexed the pages, a few minutes after
    a boot.
  - the network tools the notes use: `ping`, `traceroute`, `nslookup`,
    `nc`, `socat`
- **Programs of their own:** `nix profile install nixpkgs#<name>`, or
  `nix shell nixpkgs#<name>` to try one without installing it.
  - `apt` only prints that hint.
  - A C library installed this way is not one gcc links against. For that,
    work inside `nix-shell -p <library>`.
- **What the notes assume of Ubuntu:**
  - `-lcurses`, `-lncurses` and `#include <curses.h>` work as with Debian's
    `libncurses-dev`.
  - `/usr/include` exists for reading (`asm/unistd_64.h` and the rest).
  - VS Code's Remote-SSH works, through nix-ld.
- **Limits per login:**
  - 2 cores
  - 2 GiB of memory, squeezed from 1.5 GiB
  - 512 tasks, which stops the processes class's fork bomb

  root has no limits.
- **Isolation:**
  - Homes are `0700` and nobody has sudo.
  - `ptrace` reaches only a student's own children.
  - `ps` still shows everyone's processes. NixOS removed `hidepid` because
    it breaks under cgroups v2.

### What a shared machine changes in the labs

Some of the notes assume a machine of one's own:

- **Fixed ports.** The socket labs listen on 8080 and 8181, so only the first
  student gets the port. Have each student pick their own port.
- **Fixed names.** `sem_open` and `shm_open` use fixed names
  (`"multiprocessing_introduction"`, `"bobcho"`). Whoever runs first owns the
  object and everyone else gets `EACCES`. Prefix the names with the user
  name.
- **Root.** Exercises that need root (`dd` of `/dev/sda`,
  `/dev/input/mice`, `mount`) don't run here.

## SSH from the internet

Students log in with their passwords, or with their own keys once they have
put them in `~/.ssh/authorized_keys`. No other account takes a password, and
root takes keys only from the home networks.

A class shares one address behind its school's NAT, so two sshd limits are
set with that in mind:

- **`MaxStartups 64:30:256`** lets 64 people sit at the password prompt at
  once.
- **`PerSourcePenalties`** blocks an address only after about 60 failed
  connections in quick succession. A guessing bot reaches that; a class
  mistyping passwords doesn't. The home networks are exempt.

## Known gaps

- **`.31` is inside Public Servers' DHCP range** (`.6`–`.254`). Either
  reserve it with a `unifi_client` once the VM's MAC is known, or move DHCP
  above `.99` as on VLANs 10 and 12. That move has to be made in the UI first
  (the `dhcp_guarding` FIXME in `tofu/unifi/networks.tf`). Until then,
  dnsmasq's ping check is what keeps it from handing the address out.
- **A reinstall starts over.** Replacing the VM wipes both disks. Homes are
  lost, and passwords go back to the initial ones on the roster. The SSH host
  key changes too, so students see a warning.
- **No disk quotas.** One student can fill `/home` for everyone, though not
  the system or the Nix store.
- **WAN failover** depends on `wan-dns` and Qoax Community's plane, as for
  the intercom ([wan-dns.md](wan-dns.md)).
