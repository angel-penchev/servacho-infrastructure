# os-tues: the operating systems class's machine

`os-tues` is where TUES' operating systems class writes and runs its assembly
and C. Every student has an account and logs in from anywhere as
`<student>@os-tues.qo.ax`. It runs NixOS, like every other host here, so it
is installed, deployed and changed by this repository. Students install extra
programs into their own accounts without root.

| Piece | Where | Managed by |
|---|---|---|
| VM 4031 on Public Servers (VLAN 4, the `Dmz` zone), `192.168.4.31`. It has 4 cores and 12 GiB, ballooning down to 4 GiB, plus a 64 GiB system disk and a 64 GiB disk for `/home` | `tofu/os_tues.tf`, with infrastructure-reusables' `nixos-vm` | tofu |
| The host: toolchain, per-login limits, SSH | `nixos/hosts/os-tues/configuration.nix` | tofu, deployed in place |
| The students' accounts | `os-tues-students` on the host (`nixos/hosts/os-tues/students.nix`, `students.py`), run by the `os-tues students` workflow from a sigma export | by hand, through the workflow (below) |
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
- **Class:** every account is in `students`, which sshd lets in with a
  password, and in its class's group, `class-<class>` (`class-11a-2026`).
  A class is retired, and restored, as a whole.

None of this is kept anywhere but on the host. The initial password exists
only as the hash in `/etc/shadow` until the student replaces it, and the
names never reach this repository, which is public, or its workflow logs,
which are public too.

## Importing a class

The `os-tues students` workflow runs `os-tues-students` on the host over SSH
from the root plane's runner. It reads the export from the repository secret
`OS_TUES_SIGMA_EXPORT`: Actions secrets can't be read back, and the only
thing a workflow passes on is what it prints.

1. In sigma's students directory, set **Статус** to `Записан`, the school
   year, and **Клас** to the class (`2026/2027 - 11А`), then **Експорт**. It
   downloads `students-directory.xlsx`.
2. Put the file in the secret:

   ```bash
   base64 -w0 ~/Downloads/<export> | gh secret set OS_TUES_SIGMA_EXPORT -R angel-penchev/servacho-infrastructure
   ```

3. Run the workflow, `import`, with the class's name:

   ```bash
   gh workflow run os-tues-students.yaml -R angel-penchev/servacho-infrastructure -f action=import -f class=11a-2027 -f grade=11А
   ```

   `grade`, which can be empty, keeps only the export's rows whose class
   column says so, in case the export has more than the filtered class.
   `max_students` (40) refuses an export that looks like the whole school.
4. Delete the export:

   ```bash
   gh secret delete OS_TUES_SIGMA_EXPORT -R angel-penchev/servacho-infrastructure
   ```

The log lists which columns it read, and counts:

- **Created:** students who got an account.
- **Already had one:** students with an account, which keeps its password and
  joins the class.
- **Skipped:** rows with no phone number, or with no single middle name (a
  name of four words). `journalctl -t os-tues-students` on the host names
  them. Give them accounts by hand (below) or fix sigma and import again.

sigma's export, as of October 2026, is one sheet with one title row: `Name`,
`Grade`, `Specialty`, `Status`, `Age`, `Elsys Email`, `Personal Email`,
`Phone Number` and `Admission Year`. `os-tues-students` takes:

- the user name from `Elsys Email`;
- the phone from `Phone Number`;
- the middle name as the middle of the three names in `Name`;
- with `grade`, the class from `Grade`.

The log's `Columns:` line says which columns it used. Columns are found by
content as much as by title, so an export with Bulgarian titles (`Телефон`,
`Имена`) or a middle name column of its own (`Презиме`) works too. If sigma
changes its export, the error lists the columns it found; the rules are in
`students.py`.

Importing again is safe: no one is created twice and no password is reset.

### Retiring a class

When a class has finished with the course:

```bash
gh workflow run os-tues-students.yaml -R angel-penchev/servacho-infrastructure -f action=retire -f class=11a-2026
```

Its accounts expire and their sessions end, and the homes stay. `restore`
lets the class back in. To remove an account and its home for good, on the
host: `userdel -r <student>`.

### A student by hand

On the host:

```bash
os-tues-students import 11a-2026 < export.csv
```

The CSV needs a title row and the student's row, with an address, a middle
name (`Презиме`) and a phone (`Телефон`).

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
- **A reinstall starts over.** Replacing the VM wipes both disks: the
  accounts and homes are gone until each class is imported again, with its
  initial passwords. The SSH host key changes too, so students see a warning.
- **No disk quotas.** One student can fill `/home` for everyone, though not
  the system or the Nix store.
- **WAN failover** depends on `wan-dns` and Qoax Community's plane, as for
  the intercom ([wan-dns.md](wan-dns.md)).
