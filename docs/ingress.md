# ingress: 80 and 443 for every tenant

The home has one public address per line, so everyone on it shares one port
443. `ingress` is the small NixOS VM that the gateway's 80 and 443 lead to.
HAProxy on it sends each connection to the tenant whose name it carries:

- **443** goes by the TLS server name and is passed through unopened.
- **80** goes by the `Host` header.

The VM ends no TLS and holds no tenant's keys; each tenant ends TLS on its own
servers. A *tenant* is anyone who serves names through it: an organisation of
`tofu/organisations.tf`, or a personal service. The tenants are one file, so
adding one is a pull request.

| Piece | Where | Managed by |
|---|---|---|
| VM 4016 on Public Servers (VLAN 4, the `Dmz` zone), `192.168.4.16`. It has 1 core, 1 GiB ballooning down to 512 MiB, and a 16 GiB disk, and is in no organisation's pool | `tofu/ingress.tf`, with infrastructure-reusables' `nixos-vm` | tofu |
| The host: HAProxy, the firewall, SSH | `nixos/hosts/ingress/configuration.nix`, `haproxy.nix` | tofu, deployed in place |
| The VM's address, prefix and gateway, their one copy | `nixos/hosts/ingress/vm.json`, which the host, `tofu/ingress.tf` and `tofu/unifi/ingress.tf` read; the plan fails if it leaves Public Servers | a pull request; moving the VM takes more ([Known gaps](#known-gaps)) |
| The tenants | `nixos/hosts/ingress/tenants.json` | a pull request ([Adding a tenant](#adding-a-tenant)) |
| One `Dmz → Internal` policy per tenant, from the VM to its servers' addresses and ports | `unifi_firewall_policy.ingress`, `tofu/unifi/ingress.tf`, from the same file | tofu |
| The reservation of `192.168.4.16` | not yet ([The reservation](#the-reservation)) | the UI, then tofu |
| TCP 80 and 443 on both WANs → `192.168.4.16` | not yet ([The forward](#the-forward)) | the UI, then tofu |

Nothing has served the home's 80 and 443 since `192.168.5.58` was shut down
(below), and there are no tenants yet: `tenants.json` is `{}`.

## How it routes

- **443:** HAProxy waits up to 5 s for the TLS ClientHello and reads the
  server name in it. An exact name in a tenant's `names` wins over a suffix.
  The connection then goes, unopened, to one of the tenant's `https` servers.
  A connection with no name, or with a name no tenant claims, is closed:
  there is no default backend.
- **80:** the `Host` header, without its port, picks the tenant the same way.
  - The tenant's `http` servers answer ACME HTTP-01 challenges and redirect
    to HTTPS.
  - A tenant with no `http` servers gets the redirect to `https://` from
    HAProxy itself.
  - A name no tenant claims gets a 404.
- **The visitor's address:** the forward changes only the destination, so
  HAProxy sees the visitor's own address. A tenant with `proxy_protocol` gets
  it in a PROXY v2 header on both ports. Every other tenant gets the
  connection with nothing added, from the VM's address.
- **Health checks:** every server every 5 s, down after 2 failures. A
  connection that fails is retried on the tenant's next server.
- **Limits:**
  - 4,096 connections in all, about 135 MB;
  - 2 s for a server to accept a connection;
  - a 443 connection closes after 5 minutes of silence, so held streams and
    WebSockets stay open;
  - a request on 80 has 10 s to send its headers.
- **Changes:** a deploy that changes the configuration reloads HAProxy rather
  than restarting it. New workers take the listeners over, and the old ones
  keep their connections until those close, for 30 minutes at most.

## Adding a tenant

1. **Add it to `nixos/hosts/ingress/tenants.json`**, under a short name of
   lower-case letters, digits and dashes:

   ```json
   {
     "yourorg": {
       "names": ["yourorg.example", ".yourorg.example"],
       "https": ["192.168.12.40:443"],
       "http": ["192.168.12.40:80"],
       "proxy_protocol": true
     }
   }
   ```

   - `names` lists exact names, and suffixes with a leading dot, each of
     which covers every name under it. `.yourorg.example` covers
     `www.yourorg.example`, but not `yourorg.example` itself, hence both, nor
     `badyourorg.example`.
   - `https` lists the servers for 443, as `address:port`, on Public
     Servers, Private Servers, Qoax VPS or FMI{Codes} VPS
     (`ingress_server_networks` in `tofu/unifi/ingress.tf`). Step 3 says
     which addresses on them are refused.
   - `http` lists the servers for 80, on the same networks. Leave it out,
     and HAProxy redirects to HTTPS itself.
   - `proxy_protocol` is `true` when the servers expect a PROXY v2 header,
     on both ports. Left out, it is `false`.
2. **Open the tenant's own firewall** to 80 and 443 (or the ports above)
   from `192.168.4.16` alone. With `proxy_protocol`, trust the header from
   that address alone, for example in Traefik's `proxyProtocol.trustedIPs`.
   The address is `address` in `nixos/hosts/ingress/vm.json`; should it
   change, these must change with it.
3. **Open a pull request.** Its plan fails if:
   - two tenants claim the same name;
   - one tenant's suffix covers another tenant's name;
   - an entry has a field it shouldn't, or a value of the wrong shape;
   - a server is the VM itself, or its gateway: `192.168.4.1` would publish
     the UniFi console;
   - HAProxy rejects the configuration, or warns about it (`haproxy -c`);
   - a server is on a network other than the four in step 1: Main,
     Default, UniFi Devices, Guest, IoT or a VPN's pool;
   - a server is another network's gateway, or an infrastructure host
     reserved in `tofu/unifi/clients.tf`: the Proxmox host, a management
     plane or a JetKVM.

   The error names the entries. The first five are the VM's system build,
   which also builds on its own on x86_64-linux Nix such as the root
   plane's:

   ```bash
   nix build ./nixos#checks.x86_64-linux.ingress-haproxy
   ```

   The last two are `terraform_data.ingress_checks` in
   `tofu/unifi/ingress.tf`, which only the plan runs.

   A good plan replaces
   `module.ingress.module.deploy.null_resource.nixos-rebuild`,
   which redeploys the VM, and adds
   `module.unifi.unifi_firewall_policy.ingress["yourorg"]`. A tenant whose
   servers are all on Public Servers gets no policy: the VM reaches them on
   its own network, without the gateway.
4. **Merge.** The apply creates the policy and deploys the new configuration.
5. **Point the tenant's names at the home's lines.**
   - Qoax Community's records follow the active line through `wan-dns`
     ([wan-dns.md](wan-dns.md)). Other tenants handle their own.
   - A name Cloudflare proxies can use an Origin CA certificate under Full
     (strict). A name it doesn't proxy can get one from ACME HTTP-01 through
     port 80.

Removing a tenant is the reverse: delete its entry, and the apply removes its
policy and deploys the configuration without it.

## The firewall

The VM's own rules are nftables, in `networking.firewall.extraInputRules`:

| Port | From |
|---|---|
| 80, 443 | Any address outside the private ranges, which is what the forward delivers, and the gateway's own, `192.168.4.1`, which NAT loopback uses. No other private address. |
| 22; 8405, HAProxy's Prometheus exporter at `/metrics` | The root plane (`192.168.5.15`), which deploys the VM; Main (`192.168.2.0/24`); the Teleport, OpenVPN and WireGuard subnets (`192.168.7.0/24` to `192.168.9.0/24`) |

The exporter's line gets the monitoring VM of #68 once that has an address.

On the gateway, `Dmz → Internal` is blocked, so the VM reaches only what a
tenant's policy opens. Internal, the VPNs and the gateway may reach the VM,
whose own rules then admit only the sources above.

## Logs

HAProxy writes one line per connection on 443, and one per request on 80, to
the journal: `journalctl -u haproxy` on the VM, as root from Main or a VPN.
A line on 443 reads:

```text
203.0.113.7:51234 https yourorg.example https-yourorg/192.168.12.40:443 1/0/2 2302 -- 1/1/0/0/0 0/0
```

That is the visitor's address, the frontend, the server name, the tenant's
backend and server, then HAProxy's timers, bytes, termination state and
counters. A closed connection shows `<NOSRV>` for the server. Lines on 80 add
the status and the request line. The `base` module caps the journal at 1 GiB.

## Still to do by hand

The apply that merges this creates and installs the VM. The steps below need
the controller or the Proxmox host, so they are not code yet.

### What 192.168.5.58 was

The internet's 80 and 443 used to go to `192.168.5.58`, which ran Nginx Proxy
Manager for some self-hosted services. It is shut down, and nothing records it
yet. Before the controller's factory reset the same ports went to
`192.168.5.102`, "Personal Server Nginx Proxy Manager". Record here:

1. Its client entry on the controller: its MAC and its name. The forward
   that sent it 80 and 443 is gone (it last pointed at soki, and was removed
   with soki's forwards), so the client entry and the drift report are what
   is left (`docs/unifi-manual-vs-tofu.md`, *NGINX Server*).
2. Whether it is a Proxmox guest. A MAC that starts with `bc:24:11` is one.
   Match it against the guests on Servacho-Gosho:

   ```bash
   grep -il '<mac>' /etc/pve/qemu-server/*.conf /etc/pve/lxc/*.conf
   ```

3. The names it served and the servers it sent them to. Two places show
   them: Nginx Proxy Manager's configuration on its disk, and the DNS records
   that point at the home's lines. Those names can't be reached from outside
   while it is off. Any that should come back becomes a tenant.
4. If it is a guest, its memory.

### The reservation

Public Servers' DHCP hands out `.6`–`.254`, and `.16` is in that range. Once
the VM exists, reserve its address with its MAC, as the planes' addresses
are:

1. Read the VM's MAC: Proxmox → VM 4016 → Hardware → Network Device, or
   `qm config 4016 | grep net0` on Servacho-Gosho.
2. In the UniFi UI, set the client's name to `ingress` and its fixed IP to
   `192.168.4.16`, the address in `nixos/hosts/ingress/vm.json`, then read
   it back. Log it in [unifi-browser-changes.md](unifi-browser-changes.md).
3. Mirror it in `tofu/unifi/clients.tf`, taking the address from `vm.json`
   as `tofu/unifi/ingress.tf` reads it, and adopt it with an `import` block
   in `tofu/imports_unifi.tf`, as for the Mac mini:

   ```hcl
   # The ingress VM, VM 4016 (docs/ingress.md). Its address is static in the
   # host configuration, from nixos/hosts/ingress/vm.json (local.ingress_vm,
   # ingress.tf); the reservation keeps DHCP from handing it to anything
   # else.
   resource "unifi_client" "ingress" {
     mac            = "<mac>"
     name           = "ingress"
     fixed_ip       = local.ingress_vm.address
     allow_existing = true
   }
   ```

   ```hcl
   import {
     id = "<mac>"
     to = module.unifi.unifi_client.ingress
   }
   ```

The plan imports one client and changes nothing. Remove the `import` block in
a later change.

### The forward

The VM takes the internet's 80 and 443 as soon as it answers; nothing has to
keep working through `192.168.5.58`. Make the forward in the UI and import it.
Never create it from code: from provider 0.62.0 on, a forward created without
`enabled = true` comes up disabled.

1. In the UniFi UI, Settings → Policy Engine → NAT, create a port forward:
   - name `ingress`;
   - protocol TCP: HAProxy routes no UDP, and Cloudflare reaches an origin
     over TCP;
   - both WANs, so a tenant whose records follow the active line keeps
     working after a failover (#70);
   - from any source, ports `80,443`, to `192.168.4.16`, ports `80,443`.
2. Read it back, `GET /proxy/network/api/s/default/rest/portforward`, and
   note its `_id`. Log it in
   [unifi-browser-changes.md](unifi-browser-changes.md).
3. Mirror it in `tofu/unifi/port_forwards.tf`, and adopt it by its `_id`
   with an `import` block in `tofu/imports_unifi.tf`:

   ```hcl
   # The ingress VM, which sends 80 and 443 to each tenant by name
   # (docs/ingress.md). TCP, which is all HAProxy routes; on both WANs, so
   # that a tenant whose records follow the active line keeps working after
   # a failover.
   resource "unifi_port_forward" "ingress" {
     name     = "ingress"
     protocol = "tcp"

     wan = {
       interface  = "both"
       ip_address = "any"
       port       = "80,443"
     }

     forward = {
       ip   = unifi_client.ingress.fixed_ip
       port = "80,443"
     }
   }
   ```

   ```hcl
   import {
     id = "<_id>"
     to = module.unifi.unifi_port_forward.ingress
   }
   ```

   The plan imports one forward and changes nothing. Remove the `import`
   block in a later change.
4. Check from outside the home, for example from a phone on mobile data:
   - a tenant's name on 443 reaches its server;
   - an unknown name, or the bare address, is closed;
   - port 80 answers a known name, and gives a 404 for an unknown one;
   - HAProxy's log shows the phone's address, not the gateway's.

   Until the first tenant, only the last three apply.

### Removing the machine at 192.168.5.58

In a pull request of its own that updates this file:

1. Keep the machine, or a backup of it, for a few weeks, in case a service it
   fronted is missed.
2. Then remove it, and if it is a guest of the host, record the memory it
   frees.

## Known gaps

- **`.16` is inside Public Servers' DHCP range** until
  [the reservation](#the-reservation) exists. Until then, dnsmasq's ping
  check is what keeps it from handing the address out.
- **One VM on one host.** It fails with the host, as everything else here
  does.
- **Moving the VM is more than an edit of `vm.json`.** A pull request that
  changes only `address` fails its apply.
  `module.ingress.module.deploy.null_resource.nixos-rebuild` looks for the
  VM at the new address, where nothing answers yet, and gives up after 11
  tries. The same apply moves the tenants' policies, and once they are
  code, the reservation and the forward, to that empty address. Change
  `vm_id` in `tofu/ingress.tf` with it, as the VM id rule says, so that the
  apply replaces the VM and installs it at the new address. The VM keeps
  no state. Every tenant is down until the install ends, and the
  reservation's MAC then changes in a later pull request. To keep VM 4016
  instead, switch it by hand from the root plane before the merge
  (`nixos-rebuild switch --flake ./nixos#ingress --target-host root@192.168.4.16`);
  every tenant is cut off from that switch until the apply ends. Either
  way, the tenants' firewalls and PROXY trust
  ([Adding a tenant](#adding-a-tenant), step 2) must first admit the new
  address.
- **Each tenant's records name one line at a time** (#70), even with the
  forward on both lines.
- **Nothing pins Private Servers, Qoax VPS and FMI{Codes} VPS to Internal**,
  the zone the tenants' policies open. They are in it only because no zone
  in `tofu/unifi/firewall.tf` lists them; one moved to a zone of its own
  would leave its tenants' policies matching nothing, and no plan would
  fail.
- **No source limits.** Every tenant's names are open to the whole internet.
  A tenant whose names are all behind Cloudflare could be limited to
  Cloudflare's ranges; that waits for the first tenant that asks.
