variable "nixos_flake" {
  type        = string
  description = "Absolute path of the flake holding the root plane's host."
}

variable "ssh_private_key" {
  type        = string
  sensitive   = true
  description = "The deploy key root on the plane accepts."
}
