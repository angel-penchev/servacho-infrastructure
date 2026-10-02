# NixOS

NixOS modules, the hosts built from them, and the Proxmox VM image templates.
A host is switched to in place; the management plane is deployed that way by
OpenTofu (see [docs/management-plane-nixos.md](../docs/management-plane-nixos.md)).
A template is what a Kubernetes node is before it knows its cluster: OpenTofu
clones it once per VM, cloud-init gives the clone its name, address and SSH
key, and one small k3s configuration file makes it a control-plane or worker
node of a particular cluster.

## Layout

| Path | Contents |
|---|---|
| `flake.nix` | Pins nixpkgs, exports the modules, builds the images |
| `modules/base.nix` | What every servacho VM shares: SSH by key only, the QEMU guest agent, the nftables firewall, Nix housekeeping |
| `modules/k3s-node.nix` | `servacho.k3s.*`: a k3s server or agent with its firewall, its bootstrap and the host side of Longhorn |
| `modules/management-plane.nix` | `servacho.managementPlane.*`: OpenTofu, OpenBao and an optional runner; the root plane and every tenant plane |
| `modules/proxmox-guest.nix` | The hardware of a VM cloned from one of the images, so a cloned host needs no generated hardware file |
| `images/proxmox.nix` | The VMA build, the QEMU hardware the template declares, cloud-init |
| `images/k3s-server.nix` | The control-plane ("master") template |
| `images/k3s-agent.nix` | The worker ("runner") template |
| `images/management.nix` | The management plane template the tenant planes are cloned from |
| `hosts/servacho-managment-plane/` | The root management plane, deployed by `tofu/nixos_management_plane.tf`; its `hardware-configuration.nix` and `deploy-key.pub` were committed once from the VM |
| `hosts/*-management-plane.nix` | The tenant planes, clones of the management image deployed by `tofu/tenant_management_planes.tf` (see [docs/tenant-management-planes.md](../docs/tenant-management-planes.md)) |

## The two templates

| | `k3s-server` | `k3s-agent` |
|---|---|---|
| k3s role | server: embedded etcd, the API, and workloads | agent: workloads only |
| Open to VLAN 10 (`192.168.10.0/23`) | 6443, 2379–2380, 10250 tcp; 8472 udp | 10250 tcp; 8472 udp |
| Open to any source | 80 and 443, where ServiceLB publishes Traefik | the same |
| Longhorn host side | iSCSI initiator, NFS client, `dm_crypt`, tool paths | the same |
| Hardware in the archive | virtio-scsi-single, SeaBIOS, 4 cores, 8 GiB, `x86-64-v2-AES`, cloud-init drive on `ide2` | the same |

Both trust the `cni0` and `flannel.1` interfaces, drain pods on shutdown, allow
root in by key only, run the QEMU guest agent, and track nixpkgs 26.05. The
prod and dev clusters of qoaxhack are three servers, and one server plus one
agent, of these.

## Building

Needs Nix with flakes on x86_64-linux; the management plane qualifies. Flakes
only see files git knows about, so new files must at least be staged.

```bash
nix build ./nixos#k3s-server-image
```

```bash
nix build ./nixos#k3s-agent-image
```

Each leaves `result/vzdump-qemu-servacho-k3s-<role>.vma.zst`. The build runs a
helper VM to install the boot loader, so it is quick with `/dev/kvm` and slow
but fine without. To check the modules without producing images:

```bash
nix flake check ./nixos
```

## Importing into Proxmox

Copy an archive to a Proxmox node, restore it as a VM and mark it a template.
`--unique` gives the NIC a fresh MAC address.

```bash
qmrestore vzdump-qemu-servacho-k3s-server.vma.zst 9001 --storage local-lvm --unique && qm template 9001
```

The agent goes the same way under its own id. Which ids the templates keep,
and the OpenTofu that clones them, belong with the VM definitions, not here.

## From template to node

A clone boots, cloud-init applies what Proxmox hands it (host name from the VM
name, the static address, root's SSH key), and k3s waits. Its unit starts only
once `/etc/rancher/k3s/config.yaml` exists; a systemd condition, so an
unconfigured clone stays a blank node instead of initialising a cluster of one.
The file is ordinary k3s configuration and carries exactly what the image must
not:

```yaml
# first server of a cluster
token: <cluster token>
cluster-init: true
```

```yaml
# every other server, and every agent
token: <cluster token>
server: https://192.168.10.31:6443
```

Deliver it with a cloud-init `write_files` snippet or a colmena deployment key,
from the repository that owns the hosts. From then on a host configuration
imports `nixosModules.base` and `nixosModules.k3s-node` from this flake, never
the `images/` files, and rebuilds in place.

`servacho.k3s.clusterNetworks` in `images/` is the qoax VPS network from
`tofu/unifi/networks.tf`; a template for another VLAN changes that one line.
