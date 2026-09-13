variable "network_public_servers_id" {
  type = string
}

# UniFi Devices (VLAN 99): the management network every device is re-homed to.
variable "network_unifi_devices_id" {
  type = string
}

variable "port_profile_host_device_id" {
  type = string
}

variable "port_profile_iot_id" {
  type = string
}

variable "port_profile_public_servers_id" {
  type = string
}

variable "port_profile_private_servers_id" {
  type = string
}

variable "port_profile_unifi_devices_id" { type = string }


