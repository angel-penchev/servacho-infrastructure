variable "id" {
  type        = string
  description = "Short name, as in pool-<id>, tofu-<id>@pve and secret/management-planes/<id>."
}

variable "name" {
  type        = string
  description = "Display name, for the comments Proxmox shows."
}

variable "vlan" {
  type        = number
  description = "The organisation's VLAN on the bridge: its VMs' network, and its plane's."
}

variable "roles" {
  type = object({
    pool    = string
    disks   = string
    isos    = string
    network = string
  })
  description = "Roles of the organisation's OpenTofu user: on its pool, on disk_storage, on its ISO storage and on its VLAN (../roles.tf)."
}

variable "disk_storage" {
  type    = string
  default = "local-lvm"
}

variable "bridge" {
  type    = string
  default = "vmbr0"
}

variable "proxmox_endpoint" {
  type    = string
  default = "https://192.168.5.10:8006/"
}

variable "plane" {
  type = object({
    host    = string
    vm_id   = number
    address = string
  })
  default     = null
  description = "The organisation's management plane: its host in ../nixos, VM id and static address on the VLAN. null for none."

  validation {
    condition = var.plane == null || (
      var.installer_iso_id != null && var.nixos_flake != null &&
      var.openbao_cli != null && var.ssh_private_key != null
    )
    error_message = "A plane needs installer_iso_id, nixos_flake, openbao_cli and ssh_private_key (local.plane_tools in ../organisations.tf)."
  }
}

# What a plane is built with, shared by every organisation's; needed only with
# a plane.

variable "node_name" {
  type    = string
  default = "Servacho-Gosho"
}

variable "installer_iso_id" {
  type        = string
  default     = null
  description = "The installer the plane boots from, from infrastructure-reusables' installer-iso."
}

variable "nixos_flake" {
  type        = string
  default     = null
  description = "Absolute path of the flake holding the plane's host."
}

variable "openbao_cli" {
  type        = string
  default     = null
  description = "Path of the bao binary the OpenBao bootstrap runs."
}

variable "ssh_private_key" {
  type        = string
  default     = null
  sensitive   = true
  description = "The root plane's deploy key, which the installer and the plane's root accept."
}
