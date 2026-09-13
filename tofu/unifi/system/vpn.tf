# ----------------------------------------------------------------------------
# Remote-access VPN servers -- three of them, decided 2026-09-13, one tunnel subnet
# each, following the VLAN-ID-equals-third-octet convention of the LAN networks:
#
#   1. Teleport / WiFiman   192.168.7.1/24   (UI-only, see FIXME below)
#   2. StKr OpenVPN Server  192.168.8.1/24   unifi_vpn_server.openvpn
#   3. StKr WireGuard Server 192.168.9.1/24  unifi_vpn_server.wireguard
#
# All three land in the controller's default `Vpn` firewall zone (Vpn -> Internal,
# External, Gateway, Hotspot, Dmz allowed; Vpn -> IoT blocked). Nothing in
# ../security/firewall.tf touches that zone yet.
#
# Discipline is the same as everywhere else in this module: the controller is
# configured first (UI or API), read back, and mirrored here. See
# docs/unifi-browser-changes.md (2026-09-13, "VPN servers").
# ----------------------------------------------------------------------------

# 1. Teleport (the WiFiman app's one-tap VPN). Enabled live since the rebuild and the
# admin's current way in, so it is never touched from code.
#
# FIXME(unifi): not expressible at provider v0.55.0. Teleport is not a network
# (`/rest/networkconf`) but a site setting (`/get/setting` key `teleport`,
# `{enabled: true, subnet_cidr: "192.168.7.1/24"}`), and `unifi_setting` has no
# `teleport` block (blocks at v0.55.0: auto_speedtest, country, doh, dpi, igmp_snooping,
# ips, lcm, mgmt, network_optimization, ntp, radius, syslog, usg). It also has no name
# -- the UI shows it as "Teleport", so the "StKr <x> Server" convention cannot apply.
# Live values, verified 2026-09-13:
#   enabled      = true
#   subnet_cidr  = "192.168.7.1/24"
# Related and equally UI-only: `magic_site_to_site_vpn` (Site Magic) is enabled with
# controller-generated keys and no tunnels -- the controller default, left alone.

# 2. OpenVPN, authenticated against the built-in RADIUS profile (the four accounts in
# ../security/radius.tf). Created in the UI on 2026-09-13; every attribute below is
# the read-back value. Certificates, DH parameters and the TLS auth key are generated
# by the controller and surface here only as computed `openvpn.*` attributes.
#
# NOTE the controller only accepts `AES_256_CBC` or `BF_CBC` as an explicit cipher
# (`api.err.InvalidValue`, verified via the API) and the UI does not send one at all;
# the earlier commented-out block asked for AES_256_GCM, which is the likely cause of
# the "constant 400 Invalid Payload" it blamed on the provider. `encryption_cipher`
# is left unset so the provider adopts whatever the controller reports.
resource "unifi_vpn_server" "openvpn" {
  name             = "StKr OpenVPN Server"
  enabled          = true
  subnet           = "192.168.8.1/24"
  radiusprofile_id = data.unifi_radius_profile.default.id

  wan = {
    interface = "wan"
    ip        = "any"
  }

  # Auto DNS Server (clients get the gateway) == dhcpd_dns_enabled false live.
  dns = {
    enabled = false
  }

  openvpn = {
    mode = "server"
    port = 1194 # UDP (vpn_protocol "UDP" live)
  }
}

# FIXME(unifi-ui-only): OpenVPN fields the UI sets that unifi_vpn_server cannot express
# (live values): vpn_protocol "UDP"; mss_clamp "auto"; interface_mtu_enabled false;
# openvpn_compression_disabled true; dhcpd_start/stop 192.168.8.2-192.168.8.254;
# setting_preference "auto". A from-scratch create lands on controller defaults.

# 3. WireGuard. Key pair: the private key lives in OpenBao at
# `secret/unifi/vpn/wireguard` (`private_key`, present 2026-09-13; public key
# mmWQkf3mwfZGD0fEHOPuF/YJV6/iBz/358J/FOIEKSw=) and reaches this module as
# var.wireguard_private_key. The controller refuses to create a WireGuard server
# without a private key (api.err.WireguardMissingPrivateKey), so live creation must use
# this same key or the two sides disagree forever.
#
# STATUS 2026-09-13: NOT YET CREATED LIVE -- see docs/unifi-browser-changes.md. Peers
# (clients) will follow as `unifi_wireguard_peer` resources (name, interface_ip,
# public_key) once the server exists; peer public keys are not secret.
resource "unifi_vpn_server" "wireguard" {
  name    = "StKr WireGuard Server"
  enabled = true
  subnet  = "192.168.9.1/24"

  wan = {
    interface = "wan"
    ip        = "any"
  }

  wireguard = {
    port        = 51820
    private_key = var.wireguard_private_key
  }
}
