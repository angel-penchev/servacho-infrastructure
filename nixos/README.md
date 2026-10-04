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
| `hosts/*-management-plane.nix` | The organisations' planes, installed and deployed by `tofu/organisation/plane.tf` (see [docs/tenant-management-planes.md](../docs/tenant-management-planes.md)) |
| `images/installer.nix` | The installer ISO an organisation's plane boots from an empty disk, letting the root plane in with its deploy key |

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

Change the tag in `flake.nix`, run `nix flake lock ./nixos`, and change the
`?ref=` of the OpenTofu modules in `tofu/organisations.tf` and `tofu/organisation/plane.tf` to the same
tag. The pull request's plan shows which hosts the new version changes.
