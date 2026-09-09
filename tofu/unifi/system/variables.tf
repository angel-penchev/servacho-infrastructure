# network_guest_id is the only network id this module still needs, and only for the
# commented-out `unifi_setting_switch.dot1x_control` block in settings.tf. The main /
# private_servers / public_servers ids were dropped on 2026-09-09 when clients.tf --
# their only consumer -- was emptied.
variable "network_guest_id" { type = string }

variable "radius_profile_secret" {
  type        = string
  description = "Shared secret for the site RADIUS server"
  sensitive   = true
}

variable "wireguard_private_key" {
  type        = string
  description = "Private key for the WireGuard VPN Server"
  sensitive   = true
}
