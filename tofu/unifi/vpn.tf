resource "unifi_vpn_server" "wireguard" {
  name    = "StKr WireGuard Server"
  enabled = true
  subnet  = "192.168.7.1/24"

  wan = {
    interface = "wan"
    ip        = "any"
  }

  wireguard = {
    port        = 51820
    private_key = var.wireguard_private_key
  }
}

resource "unifi_vpn_server" "openvpn" {
  name    = "StKr OpenVPN Server"
  enabled = true
  subnet  = "192.168.8.1/24"

  wan = {
    interface = "wan"
    ip        = "any"
  }

  lifecycle {
    ignore_changes = all
  }

  openvpn = {
    encryption_cipher = "AES_256_GCM"
    mode              = "server"
    port              = 1194
  }
}
