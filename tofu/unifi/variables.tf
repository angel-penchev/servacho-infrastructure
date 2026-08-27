variable "radius_secret" {
  type        = string
  description = "The secret for the RADIUS auth server"
  sensitive   = true
}
