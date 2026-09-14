# ----------------------------------------------------------------------------
# UniFi module -- one controller (UDM StKr, https://192.168.1.1), one site (default).
#
# This is a single flat module: every *.tf in this directory covers one topic and the
# file name says which (README.md has the map). There are no submodules -- nothing
# here is instantiated twice, so resources reference each other directly
# (`unifi_network.main.id`, `unifi_port_profile.host_device.id`) instead of through
# output -> variable plumbing. The only inputs are the secrets below; the root module
# (../providers.tf, ../unifi_module.tf) reads them from OpenBao and configures the
# provider itself.
#
# The controller is the source of truth. Changes are made in the UI or its API, read
# back, and mirrored here; `tofu apply` is not part of the workflow until every
# resource has been `tofu import`ed (docs/unifi-manual-vs-tofu.md).
# ----------------------------------------------------------------------------

terraform {
  required_providers {
    unifi = {
      source  = "ubiquiti-community/unifi"
      version = "~> 0.55.0"
    }
  }
}

# ----------------------------------------------------------------------------
# Inputs -- secrets only, all from OpenBao via ../unifi_module.tf
# ----------------------------------------------------------------------------

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

# ----------------------------------------------------------------------------
# Controller-managed objects shared by more than one file (data sources)
# ----------------------------------------------------------------------------

# The built-in RADIUS profile ("Default", use_usg_auth_server = true). Referenced by
# the StKr WLAN (wlans.tf) and the OpenVPN server (vpn.tf). The users it authenticates
# are in radius.tf, the server itself is the `radius` block in settings.tf.
data "unifi_radius_profile" "default" {
  name = "Default"
}
