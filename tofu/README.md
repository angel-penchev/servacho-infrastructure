# OpenTofu

What the root management plane applies. The state is local to the plane
(`providers.tf`); CI plans every pull request and applies `main`.

| Path | Contents |
|---|---|
| `providers.tf` | Backend, provider pins, the provider credentials read from the root OpenBao |
| `roles.tf` | `TofuProvisioner`, the role each organisation's OpenTofu user has on its pool |
| `root_plane.tf`, `root-plane/` | The root management plane: its VM and the NixOS deployed onto it ([docs/management-plane-nixos.md](../docs/management-plane-nixos.md)) |
| `organisations.tf`, `organisation/` | One `organisation` per organisation: its pool, OpenTofu user and token, the token's copy in the root OpenBao, and its management plane ([docs/tenant-management-planes.md](../docs/tenant-management-planes.md)) |
| `unifi_module.tf`, `unifi/` | The UniFi controller ([unifi/README.md](unifi/README.md)) |

`organisation/` is instantiated once per organisation, so its resources are
written once and named generically (`proxmox_virtual_environment_pool.this`);
`root-plane/` and `unifi/` are single instances kept in their own directory to
group them. The `moved` blocks in `root_plane.tf` and `organisations.tf` record
where the resources lived before; they can go once every state has been
applied past them.

Adding an organisation is one more `module "<id>"` call in `organisations.tf`,
plus its VLAN in `unifi/networks.tf` and, for a plane, its host in
`../nixos/hosts/`.
