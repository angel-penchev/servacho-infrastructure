# The networks administrators open SSH connections from, for
# servacho.ssh.sources. A host adds its deployer to the list. If one of
# these networks changes in UniFi, change this list too. Otherwise
# administrators lose SSH to each host that uses the list.
[
  # Main (tofu/unifi/networks.tf).
  "192.168.2.0/24"
  # The client subnets of the VPN servers (tofu/unifi/vpn.tf): Teleport,
  # OpenVPN and WireGuard. Only the UniFi UI sets Teleport's subnet.
  "192.168.7.0/24"
  "192.168.8.0/24"
  "192.168.9.0/24"
]
