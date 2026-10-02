# Moving the root management plane to 192.168.5.15 / VM 5015

A management plane takes `.15` of its VLAN, and a VM id is the VLAN followed
by the zero-padded last octet. The root plane predates the rule and runs at
`192.168.5.11` as VM 5011. Proxmox cannot renumber a VM, so the move is a
backup restored under the new id, with OpenTofu told to forget the old id and
adopt the new one instead of destroying and recreating the machine that runs
its own apply. Issue #38.

Five steps, three machines. Each step waits for the one before it.

## 1. Repository: forget 5011, deploy over loopback

A pull request (the first of #38) makes two changes and plans as "1 to
forget": the self-deploy in `tofu/nixos_management_plane.tf` targets
`127.0.0.1`, so changing the plane's LAN address later cannot cut the session
doing the switch, and `tofu/vms.tf` replaces the VM resource with a `removed`
block with `destroy = false`. After it merges, the VM is unmanaged for the
duration of steps 2 and 3, and nothing else changes.

## 2. Management plane, as root: record the network before the move

```sh
ip -br addr && nmcli -t -f DEVICE,TYPE,STATE,CONNECTION device && nmcli -t -f NAME,TYPE,DEVICE,IP4.ADDRESS,IP4.METHOD connection show --active
```

This says which device holds `192.168.5.11` and whether it is static or a
DHCP lease. The host configuration names `eth0`; if the device is `ens18`, the
static block has been ignored and the address comes from a lease, which decides
how step 4 writes the new address.

On 2026-10-02 it showed `eth0` holding `192.168.5.11/24`, which NetworkManager
reported as `connected (externally)`: the static address in the host
configuration is the one in use, applied by NixOS's own networking, so step 4
only changes that address. The last `nmcli` part errors on `IP4.ADDRESS`, a
field only a named connection has; `ip -br addr` already answers the question.

## 3. Proxmox host, as root: restore the VM under 5015

The backup goes to the `local` directory storage. The restore keeps the MAC
address, so the guest sees the same network device.

```sh
qm shutdown 5011 --timeout 180 && qm status 5011
```

```sh
vzdump 5011 --storage local --mode stop --compress zstd --notes-template 'before move to 5015'
```

```sh
qmrestore "$(ls -t /var/lib/vz/dump/vzdump-qemu-5011-*.vma.zst | head -1)" 5015 --storage local-lvm && qm start 5015
```

The restored VM boots the same disk: same address for now, same OpenBao data
(sealed, as after any restart), same runner registration, same state file.
Within a minute the runner shows online in the repository's settings, and the
next workflow run unseals OpenBao. Leave 5011 stopped; do not destroy it yet.

## 4. Repository: adopt 5015 and move the address

The second pull request puts the VM resource back with `vm_id = 5015` and an
`import` block for `Servacho-Gosho/5015`, moves the host configuration to
`192.168.5.15` in the way step 2 showed to be right, and updates every
document that names the old address. Its plan shows "1 to import" and the
system build for the new address. On merge the apply imports the VM and
switches the plane; the address changes under the runner, which reconnects
to GitHub on its own, and the job finishes over loopback.

If the plane does not come back on `192.168.5.15`, open its console in
Proxmox and boot the previous generation from GRUB; the old address returns
with it.

## 5. Afterwards

- A later pull request may drop the `import` block from `tofu/vms.tf`. Once
  the VM is in state the block is inert, so this is tidying, not a fix.
- SSH from a workstation uses the new address; the host key is unchanged.
- The qoaxhack specification already names `192.168.5.15` and 5015.
- Once 5015 has run for a few days, on the Proxmox host:

  ```sh
  qm destroy 5011 --purge
  ```

  and remove the backup file from `/var/lib/vz/dump` when the disk needs it.
- Both `.11` and `.15` lie inside VLAN 5's DHCP pool (`.6`–`.254`), as the
  old address always did. Narrowing the pool or reserving `.15` in UniFi is a
  separate change.
