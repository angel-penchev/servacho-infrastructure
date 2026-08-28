variable "network_main_id" { type = string }
variable "network_iot_id" { type = string }
variable "network_public_servers_id" { type = string }

variable "radius_users_passwords" {
  type        = map(string)
  description = "Map of RADIUS usernames to their respective passwords"
  sensitive   = true
}
