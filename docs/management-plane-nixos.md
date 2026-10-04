# Management plane: NixOS deployed by OpenTofu

The management VM's operating system is part of the same OpenTofu run as its
VM. `tofu/root-plane/` builds
`nixosConfigurations.servacho-management-plane` from `nixos/`, and when the
built system differs from the one it last deployed, copies it to the VM over
SSH and switches to it. The build happens at plan time, so a pull request's
plan shows whether merging it would change the machine.

Two files the host needs are not in git and cannot be, until you put them
there. Until both are committed the flake refuses to evaluate this host and
says which one is missing.

## One-time bootstrap

Everything below runs on the management VM, as root, from a checkout of this
repository.

1. **Commit the hardware description.** `nixos-generate-config` wrote it at
   install time; it holds the root filesystem's UUID, which nothing else can
   supply.

   ```sh
   cp /etc/nixos/hardware-configuration.nix nixos/hosts/servacho-managment-plane/
   ```

2. **Create the deploy key.** Its public half goes into the repository and
   into root's authorized keys through the NixOS configuration; the private
   half goes into OpenBao, where the runner reads it as a Vault data source.

   ```sh
   ssh-keygen -t ed25519 -N "" -C "servacho-infrastructure deploy" -f /root/deploy-key
   cp /root/deploy-key.pub nixos/hosts/servacho-managment-plane/deploy-key.pub
   BAO_ADDR=http://127.0.0.1:8200 bao kv put secret/management-plane/ssh private_key=@/root/deploy-key
   shred -u /root/deploy-key
   ```

   If the runner token of [openbao-bootstrap.md](openbao-bootstrap.md) is in
   use rather than the root token, its policy needs `read` on
   `secret/data/management-plane/ssh` as well.

3. **Switch by hand once.** The running system predates the flake: it has no
   deploy key, its runner lacks `jq` and `ssh`, and its `nix.conf` does not
   enable flakes. The first switch has to come from a shell on the machine.

   ```sh
   git add nixos/hosts/servacho-managment-plane
   nixos-rebuild switch --flake ./nixos#servacho-management-plane \
     --extra-experimental-features "nix-command flakes"
   ```

   This also moves the host from its channel to the flake's pinned nixpkgs
   (26.05), which upgrades OpenTofu, OpenBao and the runner in one step.
   OpenBao comes back sealed after its restart; the workflows' auto-unseal step
   handles that on their next run.

4. **Commit and push** the two files. From the next merge on, the runner
   deploys every change under `nixos/` that touches this host.

## How a deployment behaves

- The runner builds the closure as its own service user, through the Nix
  daemon, and `nix copy` to the machine it runs on finds everything present.
- The switch restarts every changed unit except the runner's own, which is
  excluded in the configuration so the job that runs the switch survives. A new
  runner version takes effect at the next reboot or `systemctl restart
  github-runner-management-runner`.
- If OpenBao's unit changes, the switch restarts it and it comes back sealed.
  Nothing in the same run needs it after plan time; the next run unseals it.
- A configuration that cannot activate leaves the previous generation
  selectable in GRUB, as any NixOS switch does. Restoring the VM from a Proxmox
  backup is the fallback for a machine that no longer boots.
