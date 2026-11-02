# The ingress VM's way to its tenants (docs/ingress.md): one policy per
# tenant, from the VM to its servers' addresses on their ports, read from the
# same tenant file as the VM's HAProxy. Dmz -> Internal is blocked otherwise.
# Unlike the rest of this module, these are not made in the UI first: the
# tenant file is their source of truth and the apply creates them, as it
# created the intercom's forward. An empty file plans none.

locals {
  # The VM's static address (../ingress/main.tf, ../../nixos/hosts/ingress/);
  # unifi_client.ingress.fixed_ip once clients.tf reserves it.
  ingress_address = "192.168.4.16"

  ingress_tenants = jsondecode(file("${path.module}/../../nixos/hosts/ingress/tenants.json"))

  # Each tenant's servers, 443's and 80's, as address and port. Servers on
  # Public Servers share the VM's network and are reached without the
  # gateway, so they need no policy.
  ingress_servers = {
    for tenant, t in local.ingress_tenants : tenant => [
      for server in concat(t.https, try(t.http, [])) : {
        address = split(":", server)[0]
        port    = tonumber(split(":", server)[1])
      }
      if !cidrcontains(unifi_network.public_servers.subnet, split(":", server)[0])
    ]
  }
}

# A tenant's ports are opened on each of its addresses: one policy per
# tenant, rather than one per server.
resource "unifi_firewall_policy" "ingress" {
  for_each = {
    for tenant, servers in local.ingress_servers : tenant => servers
    if length(servers) > 0
  }

  name                 = "Allow ingress to ${each.key}"
  action               = "ALLOW"
  ip_version           = "IPV4"
  protocol             = "tcp"
  create_allow_respond = true
  logging              = false

  source = {
    zone_id         = unifi_firewall_zone.dmz.id
    matching_target = "IP"
    ips             = [local.ingress_address]
  }

  destination = {
    zone_id            = data.unifi_firewall_zone.internal.id
    matching_target    = "IP"
    ips                = sort(distinct(each.value[*].address))
    port_matching_type = "SPECIFIC"
    # In numeric order, 80 before 443.
    port = join(",", [
      for port in sort(distinct([for s in each.value : format("%05d", s.port)])) : tostring(tonumber(port))
    ])
  }
}
