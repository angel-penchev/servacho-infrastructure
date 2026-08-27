variable "radius_profile_secret" {
  type        = string
  description = "The secret for the RADIUS auth server profile"
  sensitive   = true
}

variable "radius_users_passwords" {
  type        = map(string)
  description = "Map of RADIUS usernames to their respective passwords"
  sensitive   = true
}
