# Tenant management planes

Every tenant pool gets its own management plane: a VM in the pool, on the
tenant's VLAN, holding that tenant's OpenTofu state, its OpenBao and, once the
tenant has an infrastructure repository, the runner that applies it. A tenant
pipeline then cannot read another tenant's state or secrets, because they are
on a machine it cannot reach. This is Phase 5 of [guide.md](guide.md), done
the way this repository now works: a NixOS module shared with the root plane,
an installer ISO OpenTofu boots each VM from, nixos-anywhere to install the
host onto its disk, and the host switched to in place by later runs.

## Addresses

A management plane takes `.15` of its VLAN. VM ids follow the rule from Phase
7 of the guide: the VLAN followed by the zero-padded last octet.

| Host | Pool | VLAN | Address | VM id | Status |
|---|---|---|---|---|---|
| `servacho-management-plane` (root) | — | 5 (`192.168.5.0/24`) | `192.168.5.15` | 5015 | running; moved from `.11` / 5011 on 2026-10-02 ([management-plane-move.md](management-plane-move.md)) |
| `qoax-community-management-plane` | `pool-qoax-community` | 10 (`192.168.10.0/23`) | `192.168.10.15` | 10015 | defined, created when enabled |
| `fmicodes-management-plane` | `pool-fmicodes` | 12 (`192.168.12.0/24`) | `192.168.12.15` | 12015 | defined, created when enabled |

Addresses inside an organisation's VLAN other than its plane's are that
organisation's to allocate, in its own infrastructure repository (Qoax
Community's are in qoax-community/qoax-infrastructure). Qoax Community
Broadcast has a pool and a token but no VLAN; whether it gets a plane of its
own is open.

## Who owns what

| | servacho-infrastructure (this repository) | The organisation's repository |
|---|---|---|
| Pool, Proxmox user and token, VLAN | ✓ | |
| The plane's VM, install, host configuration, OpenBao bootstrap | ✓ | |
| What the plane's runner applies: VMs, clusters and services in the pool | | ✓ |
| Secrets for that, in the plane's OpenBao | the Proxmox token, seeded once | everything else |

The plane stays here because something has to create it before the
organisation's OpenTofu can run, and because its host configuration carries the
root plane's deploy key and the runner registration: an organisation that could
change it could also lock the root plane out. The organisation chooses only the
runner's repository and labels, set in its host file here.

The NixOS and OpenTofu modules both sides use are in
[infrastructure-reusables](https://github.com/angel-penchev/infrastructure-reusables):
an organisation's repository installs its own VMs with the same `nixos-vm`
module this repository installs the planes with.

## What is where

| Piece | Path |
|---|---|
| The module every plane is made of | infrastructure-reusables' `nixosModules.management-plane` |
| The VM's hardware and disk layout (disko), in place of a generated file | infrastructure-reusables' `nixosModules.proxmox-guest` |
| The installer every plane starts from | `nixos/images/installer.nix`, built as `installer-iso` |
| The tenant hosts | `nixos/hosts/qoax-community-management-plane.nix`, `nixos/hosts/fmicodes-management-plane.nix` |
| The VMs, their install, deploy and OpenBao bootstrap | `tofu/organisation/plane.tf`, with infrastructure-reusables' `installer-iso` and `nixos-vm` |
| The OpenBao bootstrap and the unseal after a reboot | `scripts/tenant-plane-openbao.sh`, `.github/actions/unseal-tenant-planes`, `.github/workflows/tenant-planes-unseal.yaml` |

A tenant host differs from the root plane in three ways, all visible in its
file: it imports the VM hardware and disk layout instead of a generated
`hardware-configuration.nix`, it takes a static address through the module's
`network` option (systemd-networkd, matched by interface type, so the device
name does not matter), and its runner is off until the tenant's repository
exists.

## Bringing a plane up

Nothing is run by hand on Proxmox or on the plane. The planes are on while
`management_planes_enabled` in `tofu/organisations.tf` is true; a new
organisation's plane is a `plane` block in its module there, a host file
under `nixos/hosts/` and its VLAN in UniFi, with DHCP for the installer above
the static addresses (from `.100`). The plan shows the installer upload, and
for each plane the VM, the install, the deploy and the OpenBao bootstrap. On
apply, from the root plane:

1. **The installer.** `nixos/images/installer.nix` is built as
   `installer-iso` and uploaded to the `local` storage through the Proxmox API.
   Only an ISO can go that way at the pinned provider; a disk image or a backup
   would need SSH to the node, which is why there is no VM template. A plan
   only evaluates the ISO's store path, which changes with anything that goes
   into it: the locked nixpkgs, the deploy key, `installer.nix`, a new
   infrastructure-reusables release. Each new one is built at apply and
   uploaded as `servacho-installer-<hash>.iso`; the planes are moved onto it,
   then the previous one is deleted. The ISO holds the minimal NixOS
   installer, the QEMU guest agent, and SSH for root with the deploy key's
   public half; no secrets and no host configuration.
2. **The VM.** Each plane is created in its pool and VLAN with an empty
   32 GiB disk first in the boot order, so SeaBIOS falls through to the
   installer. The installer takes a DHCP address, its guest agent starts only
   once it has one, and the VM resource waits for the agent.
3. **The install.** nixos-anywhere connects to that address with the root
   plane's deploy key, partitions the disk with the host's disko layout,
   installs the host configuration and reboots. The plane comes up from its
   disk on its static `.15` address. This happens once per VM OpenTofu
   creates: a VM it replaces installs again, and a VM restored from a backup
   under the same id is left alone (`tofu apply -replace` on the plane's
   `terraform_data.installation` reinstalls one on purpose).
4. **The deploy.** As for the root plane: from then on a change to a tenant
   host under `nixos/` shows in a plan and reaches the VM on merge.
5. **OpenBao.** `scripts/tenant-plane-openbao.sh bootstrap` initialises the
   plane's OpenBao (5 key shares, threshold 3), stores the unseal keys, the
   root token and the plane's address in the **root** OpenBao at
   `secret/management-planes/<tenant>` before it uses them, unseals it, enables
   `secret/` and copies the tenant's Proxmox token from the root OpenBao's
   `secret/proxmox/<tenant>_token` to the plane's `secret/proxmox`. The
   tenant's pipeline provisions with that token and never sees the root one.
   The bootstrap runs again when that token changes, so the plane's copy
   follows a rotation.

After a reboot a plane's OpenBao is sealed, like the root plane's. Every
apply, and `tenant-planes-unseal.yaml` every 30 minutes from `main`, unseals
the root OpenBao and then every plane recorded under
`secret/management-planes`; a plane that is down is a warning in the run, not
a failure. Pull request plans do not: they never need a tenant plane, and the
script would run from the pull request's branch with the root token.

The root plane holds every plane's unseal keys and root token. Tenants still
cannot read each other's secrets, since each pipeline runs on its own plane;
the root plane already created their Proxmox tokens, so this adds no trust it
did not have.

**The runner** joins when the tenant's infrastructure repository exists: set
`servacho.managementPlane.runner` in the host file (`enable`, `url`,
`labels`) and place the registration token at `/var/lib/github-runner/.token`
on the plane. Placing that token from OpenTofu, as the bootstrap does for the
Proxmox token, is the next piece of automation, left until a tenant repository
exists to register with.

## Still open

- **Unsealing without a workflow run.** A plane that reboots stays sealed
  for up to 30 minutes, until the scheduled unseal. Transit auto-unseal keyed
  by the root OpenBao would remove the wait.
- **A listener on the tenant VLAN, with TLS**, for workloads that read
  secrets from the plane (Qoax Community's clusters). The module keeps OpenBao on
  loopback until that consumer exists.
- **Human access** through Google Workspace OIDC, Phase 6 of the guide.
