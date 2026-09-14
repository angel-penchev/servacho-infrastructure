# UniFi module -- one controller (UDM StKr, https://192.168.1.1), one site (default).
#
# Flat module: one topic per file (README.md has the map), no submodules, resources
# reference each other directly. The only inputs are the secrets below; the root
# module (../providers.tf, ../unifi_module.tf) reads them from OpenBao and configures
# the provider. The controller is the source of truth: change in the UI or API, read
# back, mirror here. No apply until every resource is imported (docs/unifi-manual-vs-tofu.md).

terraform {
  required_providers {
    unifi = {
      source  = "ubiquiti-community/unifi"
      version = "~> 0.55.0"
    }
  }
}

variable "radius_profile_secret" {
  type        = string
  description = "Shared secret of the site RADIUS server (OpenBao secret/unifi/radius/profile -> secret). Used in settings.tf."
  sensitive   = true
}

variable "radius_users_passwords" {
  type        = map(string)
  description = "RADIUS username -> password (OpenBao secret/unifi/radius/users). Used in radius.tf."
  sensitive   = true
}

variable "wlan_guest_passphrase" {
  type        = string
  description = "WPA passphrase of the StKr_Guest WLAN (OpenBao secret/unifi/wlan/passphrases -> guest). Used in wlans.tf."
  sensitive   = true
}

variable "wlan_iot_passphrase" {
  type        = string
  description = "WPA passphrase of the StKr_IoT WLANs (OpenBao secret/unifi/wlan/passphrases -> iot). Used in wlans.tf."
  sensitive   = true
}

variable "wireguard_private_key" {
  type        = string
  description = "Private key of the StKr WireGuard Server (OpenBao secret/unifi/vpn/wireguard -> private_key). Used in vpn.tf."
  sensitive   = true
}

# The built-in RADIUS profile, used by the StKr WLAN (wlans.tf) and the OpenVPN server
# (vpn.tf). Its users are in radius.tf, the server settings in settings.tf.
data "unifi_radius_profile" "default" {
  name = "Default"
}
