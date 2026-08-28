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

# FIXME(unifi): The OpenVPN server block below is commented out because the upstream provider 
# has a bug where CustomizeDiff forcibly bypasses ignore_changes, causing constant 400 
# Invalid Payload API errors during PUT requests. Needs to be fixed upstream.
# resource "unifi_vpn_server" "openvpn" {
#   name             = "StKr OpenVPN Server"
#   enabled          = true
#   subnet           = "192.168.8.1/24"
#   radiusprofile_id = data.unifi_radius_profile.default.id
# 
#   wan = {
#     interface = "wan"
#     ip        = "any"
#   }
# 
#   openvpn = {
#     encryption_cipher = "AES_256_GCM"
#     mode              = "server"
#     port              = 1194
#   }
# }
