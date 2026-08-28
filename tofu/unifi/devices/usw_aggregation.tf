resource "unifi_device" "usw_aggregation" {
  mac               = "1c:6a:1b:98:38:ee"
  name              = "USW Aggregation"
  forget_on_destroy = false
  disabled          = false


  # -------------------------------------------------------------------------
  # FIXME(unifi): Port Overrides Temporarily Unmanaged
  #
  # The ubiquiti-community/unifi provider has a bug where SFP+ fiber ports 
  # omit RJ45-specific attributes (autoneg, stormctrl_*, lldpmed_enabled) 
  # from the API response. This causes OpenTofu's schema validation to crash 
  # with "inconsistent result after apply" because the expected schema does 
  # not match the returned API structure.
  #
  # Until the upstream provider is patched to handle SFP+ ports correctly, 
  # we must use `ignore_changes = [port_override]` to prevent pipeline crashes.
  # The port_override blocks below are commented out so it's clear they are 
  # currently unmanaged by OpenTofu. They remain here as documentation for 
  # when the provider is fixed.
  # -------------------------------------------------------------------------
#   port_override {
#     index           = 1
#     name            = "SFP+ 1"
#     port_profile_id = var.port_profile_private_servers_id
#     op_mode         = "switch"
#   }

  # TODO: double check this and open a PR for ubiquiti-community/unifi
  lifecycle {
    ignore_changes = [port_override]
  }
}
