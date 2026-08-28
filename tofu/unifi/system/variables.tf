variable "network_main_id" { type = string }
variable "network_guest_id" { type = string }
variable "network_private_servers_id" { type = string }
variable "network_public_servers_id" { type = string }

variable "wireguard_private_key" {
  type        = string
  description = "Private key for the WireGuard VPN Server"
  sensitive   = true
}
