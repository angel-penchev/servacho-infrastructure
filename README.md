# servacho-infrastructure
Infrastructure-as-code for my home server.

This repository owns what every organisation on the server shares: the Proxmox
host, UniFi and the VLANs, each organisation's pool, Proxmox user and token,
the root management plane, and every organisation's management plane. It is
applied from the root plane.

| Repository | Owns | Applied from |
|---|---|---|
| this one | The shared layer above | The root plane |
| [qoax-community/qoax-infrastructure](https://github.com/qoax-community/qoax-infrastructure) | Everything in Qoax Community's pool | Qoax Community's plane |
| an FMI{Codes} repository, when there is one | Everything in FMI{Codes}' pool | FMI{Codes}' plane |
| [infrastructure-reusables](https://github.com/angel-penchev/infrastructure-reusables) | The NixOS and OpenTofu modules all of the above share | — |

- `tofu/`: the OpenTofu the root plane applies; see [tofu/README.md](tofu/README.md).
- `nixos/`: the root plane's and the organisations' planes' NixOS hosts; see [nixos/README.md](nixos/README.md).
- `docs/`: runbooks, among them [tenant-management-planes.md](docs/tenant-management-planes.md).
