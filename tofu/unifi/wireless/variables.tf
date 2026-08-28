variable "network_main_id" { type = string }
variable "network_guest_id" { type = string }
variable "network_iot_id" { type = string }

variable "wlan_guest_passphrase" {
  type        = string
  description = "Passphrase for the Guest WLAN"
  sensitive   = true
}

variable "wlan_iot_passphrase" {
  type        = string
  description = "Passphrase for the IoT WLAN"
  sensitive   = true
}

