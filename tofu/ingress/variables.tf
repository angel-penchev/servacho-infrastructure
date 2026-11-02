variable "installer_iso_id" {
  type        = string
  description = "The installer the VM boots from, from infrastructure-reusables' installer-iso."
}

variable "nixos_flake" {
  type        = string
  description = "Absolute path of the flake holding the ingress host."
}

variable "ssh_private_key" {
  type        = string
  sensitive   = true
  description = "The root plane's deploy key, which the installer and the VM's root accept."
}
