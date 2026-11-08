# The ingress VM's Dmz -> Internal policies (docs/ingress.md). Unlike the
# rest of this module, they are not made in the UI first: the apply creates
# them from nixos/hosts/ingress/tenants.json.

locals {
  ingress_vm = jsondecode(file("${path.module}/../../nixos/hosts/ingress/vm.json"))

  ingress_tenants = jsondecode(file("${path.module}/../../nixos/hosts/ingress/tenants.json"))

  # The networks a tenant's servers may be on: the VM's own, and Internal's
  # but for Main, Default and UniFi Devices. One added here must be in
  # Internal, and needs its plane's reservation in ingress_not_servers.
  ingress_server_networks = [
    unifi_network.public_servers,
    unifi_network.private_servers,
    unifi_network.qoax_community_vps,
    unifi_network.fmicodes_vps,
  ]

  # Never a tenant's server: the VM, any gateway (the UniFi console) and the
  # infrastructure hosts in clients.tf, which an entry would publish by name.
  ingress_not_servers = concat(
    [local.ingress_vm.address],
    [
      for network in concat(local.ingress_server_networks, [
        unifi_network.default,
        unifi_network.unifi_devices,
        unifi_network.main,
        unifi_network.guest,
        unifi_network.iot,
      ]) : split("/", network.subnet)[0]
    ],
    # A reservation cleared in the UI is mirrored with fixed_ip = "".
    compact([
      unifi_client.servacho_gosho.fixed_ip,
      unifi_client.servacho_management_plane.fixed_ip,
      unifi_client.qoax_community_management_plane.fixed_ip,
      unifi_client.fmicodes_management_plane.fixed_ip,
      unifi_client.jetkvm_servacho_gosho.fixed_ip,
      unifi_client.jetkvm_michelangelo.fixed_ip,
    ]),
  )

  ingress_misplaced = distinct(flatten([
    for tenant, t in local.ingress_tenants : [
      for server in concat(t.https, try(t.http, [])) : "${tenant}: ${server}"
      if contains(local.ingress_not_servers, split(":", server)[0]) || !anytrue([
        for network in local.ingress_server_networks : cidrcontains(network.subnet, split(":", server)[0])
      ])
    ]
  ]))

  # Servers on Public Servers share the VM's network, so need no policy.
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

# Only this module knows the networks and reserved hosts, so haproxy.nix
# refuses just the VM and its gateway. Preconditions on the policies would
# skip the servers they leave out and an empty tenants.json, and a check
# block would only warn.
resource "terraform_data" "ingress_checks" {
  lifecycle {
    precondition {
      condition = (
        "${local.ingress_vm.gateway}/${local.ingress_vm.prefix_length}" == unifi_network.public_servers.subnet &&
        cidrcontains(unifi_network.public_servers.subnet, local.ingress_vm.address)
      )
      error_message = "nixos/hosts/ingress/vm.json puts the VM at ${local.ingress_vm.address}/${local.ingress_vm.prefix_length} through ${local.ingress_vm.gateway}: it belongs on Public Servers (${unifi_network.public_servers.subnet}), the Dmz network the ingress policies name as their source."
    }

    precondition {
      condition     = length(local.ingress_misplaced) == 0
      error_message = "nixos/hosts/ingress/tenants.json (docs/ingress.md): a tenant's servers may be on ${join(", ", local.ingress_server_networks[*].name)}, but not at the VM's own address, a network's gateway or an infrastructure host reserved in tofu/unifi/clients.tf. Refused: ${join("; ", local.ingress_misplaced)}."
    }
  }
}

# Each of a tenant's ports is open on each of its addresses.
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
    ips             = [local.ingress_vm.address]
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
