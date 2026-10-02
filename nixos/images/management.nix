# Template for a management plane: what a tenant's OpenTofu, OpenBao and
# runner VM is before it knows its tenant. OpenTofu clones it, cloud-init sets
# its address and the deploy key, and the tenant's host configuration is then
# switched to in place.
{ ... }:
{
  proxmox.qemuConf = {
    name = "servacho-management";
    cores = 2;
    memory = 4096;
  };

  servacho.managementPlane.enable = true;
}
