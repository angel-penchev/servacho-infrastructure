# The ingress VM's way to its tenants (docs/ingress.md): one policy per
# tenant, from the VM to its servers' addresses on their ports, read from the
# same tenant file as the VM's HAProxy. Dmz -> Internal is blocked otherwise.
# Unlike the rest of this module, these are not made in the UI first: the
# tenant file is their source of truth and the apply creates them, as it
# created the intercom's forward. An empty file plans none.

locals {
  # The VM's address, prefix and gateway: ../../nixos/hosts/ingress/vm.json,
  # their one copy, from which the host sets its address and ../ingress.tf
  # deploys to it. The policies name the address as their source, and the
  # VM's reservation in clients.tf will take its fixed_ip from here too.
  ingress_vm = jsondecode(file("${path.module}/../../nixos/hosts/ingress/vm.json"))

  ingress_tenants = jsondecode(file("${path.module}/../../nixos/hosts/ingress/tenants.json"))

  # The networks a tenant's servers may be on. Public Servers is the VM's own
  # and needs no policy; the others are in Internal, which the policies below
  # open. Main, Default and UniFi Devices are in Internal too, but hold
  # workstations and the network's own devices; Guest, IoT and the VPNs'
  # pools are in zones nothing opens from Dmz. A network added here for a new
  # organisation needs that organisation's plane reservation in the
  # infrastructure hosts below.
  ingress_server_networks = [
    unifi_network.public_servers,
    unifi_network.private_servers,
    unifi_network.qoax_community_vps,
    unifi_network.fmicodes_vps,
  ]

  # Never a tenant's server, whatever its network: the VM itself, which
  # would take its own connections back; every network's gateway, whose 80
  # and 443 are the UniFi console, the server networks' taken from the list
  # above, so that a network added to it brings its own; and the
  # infrastructure hosts reserved in clients.tf (the Proxmox host, the
  # management planes, the JetKVMs), which a tenant's entry would open to
  # the VM and publish by name.
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

  # Each tenant's servers, 443's and 80's, that are on none of the server
  # networks or are never servers, as "<tenant>: <address:port>".
  ingress_misplaced = distinct(flatten([
    for tenant, t in local.ingress_tenants : [
      for server in concat(t.https, try(t.http, [])) : "${tenant}: ${server}"
      if contains(local.ingress_not_servers, split(":", server)[0]) || !anytrue([
        for network in local.ingress_server_networks : cidrcontains(network.subnet, split(":", server)[0])
      ])
    ]
  ]))

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

# Fails the plan when vm.json and networks.tf disagree, or when a tenant's
# server is somewhere the VM may not reach. The conditions sit on a
# terraform_data of their own, which is nothing on the controller: a
# precondition on the policies below would run once per policy, so never for
# a server they leave out or with no tenants, and a check block would only
# warn.
resource "terraform_data" "ingress_checks" {
  lifecycle {
    # The VM is on Public Servers, the network in the Dmz zone that the
    # policies name as their source: its gateway and prefix are the
    # network's, and its address is in it.
    precondition {
      condition = (
        "${local.ingress_vm.gateway}/${local.ingress_vm.prefix_length}" == unifi_network.public_servers.subnet &&
        cidrcontains(unifi_network.public_servers.subnet, local.ingress_vm.address)
      )
      error_message = "nixos/hosts/ingress/vm.json puts the VM at ${local.ingress_vm.address}/${local.ingress_vm.prefix_length} through ${local.ingress_vm.gateway}: it belongs on Public Servers (${unifi_network.public_servers.subnet}), the Dmz network the ingress policies name as their source."
    }

    # Every tenant's server is on one of the server networks, and is not the
    # VM, a gateway or an infrastructure host. HAProxy's own check refuses
    # only the VM and its gateway.
    precondition {
      condition     = length(local.ingress_misplaced) == 0
      error_message = "nixos/hosts/ingress/tenants.json (docs/ingress.md): a tenant's servers may be on ${join(", ", local.ingress_server_networks[*].name)}, but not at the VM's own address, a network's gateway or an infrastructure host reserved in tofu/unifi/clients.tf. Refused: ${join("; ", local.ingress_misplaced)}."
    }
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
