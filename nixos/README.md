# NixOS

The management planes' NixOS hosts, and the installer the organisations'
planes start from. The modules they are made of come from
[infrastructure-reusables](https://github.com/angel-penchev/infrastructure-reusables),
pinned by tag in `flake.nix`. Anything that runs inside an organisation's pool
(its clusters, its services) belongs in that organisation's infrastructure
repository, not here.

| Path | Contents |
|---|---|
| `flake.nix` | Pins nixpkgs and infrastructure-reusables; the hosts, the installer, the `openbao` CLI |
| `hosts/servacho-managment-plane/` | The root management plane, deployed by `tofu/root-plane/`; its `hardware-configuration.nix` and `deploy-key.pub` were committed once from the VM |
| `hosts/*-management-plane.nix`, `hosts/qoax-community-management-plane/` | The organisations' planes, installed and deployed by `tofu/organisation/plane.tf` (see [docs/tenant-management-planes.md](../docs/tenant-management-planes.md)) |
| `hosts/os-tues/` | The operating systems class's machine, installed and deployed by `tofu/os_tues.tf`, with `os-tues-students`, which makes the students' accounts, sudo for its teachers, and LazyVim as everyone's `nvim` (see [docs/os-tues.md](../docs/os-tues.md)) |
| `hosts/ingress/` | The VM that routes the internet's 80 and 443 to each tenant by name, installed and deployed by `tofu/ingress.tf` at the address in `vm.json`: HAProxy built from `tenants.json`, which the flake's `ingress-haproxy` check validates (see [docs/ingress.md](../docs/ingress.md)) |
| `images/installer.nix` | The installer ISO an organisation's plane boots from an empty disk, letting the root plane in with its deploy key |
| `admin-sources.nix` | The networks administrators open SSH connections from, for a host's `servacho.ssh.sources` |
| `deployed-by-root-plane.nix` | The check that a host the root plane deploys keeps `192.168.5.15` in its SSH sources |

## SSH sources

infrastructure-reusables requires `servacho.ssh.sources` on each host built
on its `base` module: the addresses that may open SSH connections to the
host, or `"any"`. Each host here sets `"any"`, so sshd is open to every
source. A host that gets a list takes `admin-sources.nix` and adds its
deployer.

The root plane deploys the other hosts over SSH from `192.168.5.15`.
`flake.nix` adds `deployed-by-root-plane.nix` to each of them, and to each
new host. It stops the evaluation when a list leaves that address out. The
root plane deploys itself over SSH to loopback, which a list never closes.
The installer has no SSH source list.

## Building

Needs Nix with flakes on x86_64-linux; the management plane qualifies. Flakes
only see files git knows about, so new files must at least be staged.

```bash
nix flake check ./nixos
```

```bash
nix build ./nixos#installer-iso
```

The first builds every host's system; the second leaves
`result/iso/servacho-installer.iso`. Neither is needed by hand: OpenTofu
builds what it deploys.

## Updating infrastructure-reusables

The tag is in `flake.nix`, in the `?ref=` of the OpenTofu modules in
`tofu/organisations.tf`, `tofu/organisation/plane.tf`, `tofu/os_tues.tf` and
`tofu/ingress.tf`, and in each `uses:` of its actions in
`../.github/workflows/`. Change all of them to the new tag, then lock only
that input:

```bash
nix flake update reusables --flake ./nixos
```

A plain `nix flake update` also moves nixpkgs, which changes every host.
After the update, `flake.lock` must differ only in `nodes.reusables`.

`scripts/check-reusables-pins.sh` fails the plan while a pin and the lock
differ. The pull request's plan shows which hosts the new version changes.
It also shows a new installer ISO if the release changes it.
