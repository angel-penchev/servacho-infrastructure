# Three remote-access servers, one tunnel subnet each (third octet = order):
#   1. Teleport / WiFiman     192.168.7.1/24   UI-only, FIXME below
#   2. StKr OpenVPN Server    192.168.8.1/24   unifi_vpn_server.openvpn
#   3. StKr WireGuard Server  192.168.9.1/24   unifi_vpn_server.wireguard
# All land in the default `Vpn` zone; Vpn -> IoT stays blocked on purpose. WireGuard
# peers are added as devices need them.

# FIXME(unifi): Teleport is a site setting (`/get/setting` key `teleport`:
#   enabled true, subnet_cidr 192.168.7.1/24), not a network, and `unifi_setting` has
#   no `teleport` block at v0.55.0. It has no name either, so the "StKr <x> Server"
#   convention cannot apply. It is the admin's current way in -- never touch it.
#   Also UI-only: `magic_site_to_site_vpn` (Site Magic), enabled by default, no tunnels.

# Authenticates against the built-in RADIUS profile (users in radius.tf). Certificates,
# DH parameters and the TLS auth key are controller-generated, computed `openvpn.*`.
# The controller accepts only AES_256_CBC or BF_CBC as an explicit cipher, see the
# FIXME on encryption_cipher.
resource "unifi_vpn_server" "openvpn" {
  name             = "StKr OpenVPN Server"
  enabled          = true
  subnet           = "192.168.8.1/24"
  radiusprofile_id = data.unifi_radius_profile.default.id

  wan = {
    interface = "wan"
    ip        = "any"
  }

  # "Auto DNS Server" in the UI: clients get the gateway.
  dns = {
    enabled = false
  }

  openvpn = {
    mode = "server"
    port = 1194 # UDP
    # FIXME(unifi): CONCESSION. The UI sends no cipher, but the provider defaults this
    #   computed attribute to AES_256_GCM at plan time, which the controller rejects
    #   (api.err.InvalidValue), and `ignore_changes` cannot suppress a provider plan-time
    #   default. Pinning the one accepted cipher makes the write succeed; it is the
    #   controller's own default, so nothing changes on the wire.
    encryption_cipher = "AES_256_CBC"
  }

  # FIXME(unifi): the provider never reads `openvpn.mode` back from vpn_type. The plan is
  #   clean only because the first apply wrote an `openvpn_mode` key the UI never sets and
  #   the controller now stores it; a server re-created by hand brings the diff back.
}

# FIXME(unifi-ui-only): OpenVPN live values without a provider attribute: vpn_protocol
#   "UDP", mss_clamp "auto", interface_mtu_enabled false, openvpn_compression_disabled
#   true, dhcpd_start/stop 192.168.8.2-192.168.8.254, setting_preference "auto".

# Key pair: private key in OpenBao secret/unifi/vpn/wireguard (public key
# mmWQkf3mwfZGD0fEHOPuF/YJV6/iBz/358J/FOIEKSw=). The controller refuses to create a
# WireGuard server without a private key, so live was created with this same key
# -- keep the two in step. Peers, when they come, are
# `unifi_wireguard_peer` resources here: name, interface_ip from .9.2 up, public_key.
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
