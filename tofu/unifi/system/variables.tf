# Only used by the commented-out `unifi_setting_switch.dot1x_control` block in
# settings.tf. The other network ids went when clients.tf, their only consumer, emptied.
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
