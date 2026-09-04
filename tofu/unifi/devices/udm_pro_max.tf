resource "unifi_device" "udm_pro_max" {
  mac               = "28:70:4e:5c:b4:b2"
  name              = "Dream Machinacho Pro Max"
  forget_on_destroy = false
  disabled          = false

  port_override {
    index                 = 1
    name                  = "Port 1"
    op_mode               = "switch"
    forward               = "customize"
    native_networkconf_id = var.wan_secondary_id
  }

  port_override {
    index   = 2
    name    = "Port 2"
    op_mode = "switch"
    forward = "disabled"
  }

  port_override {
    index   = 3
    name    = "Port 3"
    op_mode = "switch"
    forward = "disabled"
  }

  port_override {
    index   = 4
    name    = "Port 4"
    op_mode = "switch"
    forward = "disabled"
  }

  port_override {
    index   = 5
    name    = "Port 5"
    op_mode = "switch"
    forward = "disabled"
  }

  port_override {
    index   = 6
    name    = "Port 6"
    op_mode = "switch"
    forward = "disabled"
  }

  port_override {
    index   = 7
    name    = "Port 7"
    op_mode = "switch"
    forward = "disabled"
  }

  port_override {
    index   = 8
    name    = "Port 8"
    op_mode = "switch"
    forward = "disabled"
  }

  port_override {
    index                 = 9
    name                  = "Port 9"
    op_mode               = "switch"
    forward               = "customize"
    native_networkconf_id = var.wan_primary_id
  }

  port_override {
    index           = 10
    name            = "SFP+ 1"
    op_mode         = "switch"
    forward         = "customize"
    port_profile_id = var.port_profile_private_servers_id
  }

  port_override {
    index           = 11
    name            = "SFP+ 2"
    op_mode         = "switch"
    forward         = "customize"
    port_profile_id = var.port_profile_unifi_devices_id
  }

  # FIXME(unifi): The UniFi API throws an error when trying to override WAN ports (Port 1 and Port 9).
  # We must ignore changes to port_override to avoid pipeline crashes until the provider
  # or API properly handles WAN port exclusions.
  lifecycle {
    ignore_changes = [port_override]
  }
}
