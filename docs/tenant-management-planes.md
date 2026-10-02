# Tenant management planes

Every tenant pool gets its own management plane: a VM in the pool, on the
tenant's VLAN, holding that tenant's OpenTofu state, its OpenBao and, once the
tenant has an infrastructure repository, the runner that applies it. A tenant
pipeline then cannot read another tenant's state or secrets, because they are
on a machine it cannot reach. This is Phase 5 of [guide.md](guide.md), done
the way this repository now works: a NixOS module shared with the root plane,
an image template cloned by OpenTofu, and the host switched to in place by the
same OpenTofu run.

## Addresses

A management plane takes `.15` of its VLAN. VM ids follow the rule from Phase
7 of the guide: the VLAN followed by the zero-padded last octet.

| Host | Pool | VLAN | Address | VM id | Status |
|---|---|---|---|---|---|
| `servacho-management-plane` (root) | — | 5 (`192.168.5.0/24`) | `192.168.5.15` | 5015 | running; moved from `.11` / 5011 on 2026-10-02 ([management-plane-move.md](management-plane-move.md)) |
| `qoax-community-management-plane` | `pool-qoax-community` | 10 (`192.168.10.0/23`) | `192.168.10.15` | 10015 | defined, not yet created |
| `fmicodes-management-plane` | `pool-fmicodes` | 12 (`192.168.12.0/24`) | `192.168.12.15` | 12015 | defined, not yet created |
| qoaxhack prod k3s servers | `pool-qoax-community` | 10 | `192.168.10.21`–`.23` | 10021–10023 | planned by the qoaxhack spec |
| qoaxhack dev k3s server, agent | `pool-qoax-community` | 10 | `192.168.10.26`, `.27` | 10026, 10027 | planned by the qoaxhack spec |

Two points where the qoaxhack specification and this table still differ, to be
settled on its side: it describes VLAN 10 as a `/24` (it is a `/23`), and it
plans a separate OpenBao VM at `192.168.10.10` while keeping `.15` free; here
the Qoax Community plane is that OpenBao. Qoax Community Broadcast has a pool
and a token but no VLAN; whether it gets a plane of its own is open.

## What is where

| Piece | Path |
|---|---|
| The module every plane is made of | `nixos/modules/management-plane.nix` |
| The clone's hardware, in place of a generated file | `nixos/modules/proxmox-guest.nix` |
| The image template | `nixos/images/management.nix`, built as `management-image` |
| The tenant hosts | `nixos/hosts/qoax-community-management-plane.nix`, `nixos/hosts/fmicodes-management-plane.nix` |
| The VMs, and the deploy of each host onto them | `tofu/tenant_management_planes.tf` |

A tenant host differs from the root plane in three ways, all visible in its
file: it imports the clone hardware instead of a generated
`hardware-configuration.nix`, it takes a static address through the module's
`network` option (systemd-networkd, matched by interface type, so the device
name does not matter), and its runner is off until the tenant's repository
exists.

## Bringing a plane up

1. **Build and restore the template**, once, on the management plane:

   ```sh
   nix build ./nixos#management-image
   ```

   Copy `result/vzdump-qemu-servacho-management.vma.zst` to a Proxmox node,
   then restore it under the id `tofu/tenant_management_planes.tf` expects and
   mark it a template:

   ```sh
   qmrestore vzdump-qemu-servacho-management.vma.zst 9003 --storage local-lvm --unique && qm template 9003
   ```

2. **Enable the planes.** In `tofu/tenant_management_planes.tf` set
   `tenant_management_planes_enabled = true` and open a pull request. Its
   plan shows the two VMs and, for each, the system build and the deploy. On
   merge OpenTofu clones the template into each pool, cloud-init gives the
   clone its address and the root plane's deploy key, and once SSH answers the
   host configuration is pushed and switched to. From then on a change to a
   tenant host under `nixos/` shows in a plan and reaches the VM on merge.

3. **Initialise OpenBao** on each new plane, by hand, as on the root plane
   ([openbao-bootstrap.md](openbao-bootstrap.md)): `bao operator init`, the
   unseal keys and root token kept off the machine, three unseals. Then store
   the tenant's Proxmox token, which the root OpenTofu already created and keeps
   in the root OpenBao at `secret/proxmox/<tenant>_token`, in the tenant's own
   instance, so the tenant's pipeline provisions with it and never sees the
   root one.

4. **Register the runner** when the tenant's infrastructure repository exists:
   set `servacho.managementPlane.runner` in the host file (`enable`, `url`,
   `labels`), place the registration token at `/var/lib/github-runner/.token`
   on the plane, and merge. The runner then applies that repository from the
   plane, with the tenant's state under `/var/lib/opentofu` there.

## Still open

- **Unsealing after a reboot** is manual on every plane today. Transit
  auto-unseal keyed by the root plane's OpenBao would remove it; a sealed-at-boot
  alert is the alternative the qoaxhack spec accepts.
- **A listener on the tenant VLAN, with TLS**, for workloads that read
  secrets from the plane (the qoaxhack clusters). The module keeps OpenBao on
  loopback until that consumer exists.
- **Human access** through Google Workspace OIDC, Phase 6 of the guide.
