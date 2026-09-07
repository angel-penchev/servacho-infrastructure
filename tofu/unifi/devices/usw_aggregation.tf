resource "unifi_device" "usw_aggregation" {
  mac               = "1c:6a:1b:98:38:ee"
  name              = "USW Aggregation"
  forget_on_destroy = false
  disabled          = false

  # FIXME(unifi): `config_network` is populated by modelToAPIDevice but dropped by
  # buildMinimalUpdateDevice, so at v0.55.0 it is only honoured on create/adopt --
  # an update silently discards it and the apply fails with "inconsistent result
  # after apply". Declared here so the code states the intended reality; it will not
  # take effect until upstream PR #463 ships (checked 2026-09-08).
  # https://github.com/ubiquiti-community/terraform-provider-unifi/pull/463
  config_network = {
    type    = "static"
    ip      = "192.168.1.3"
    netmask = "255.255.255.0"
    gateway = "192.168.1.1"
    dns1    = "192.168.1.1"
  }

  # FIXME(unifi): The ubiquiti-community/unifi provider crashes on apply when attempting 
  # to disable ports due to a bug parsing the empty MAC allowlist required for the new
  # UniFi OS Port State toggles.
  # Tracking PR: https://github.com/ubiquiti-community/terraform-provider-unifi/pull/470
  # Until it is merged, we must ignore port_override changes so they can be disabled via the UI.
  lifecycle {
    ignore_changes = [port_override]
  }

  # TODO(port-overrides): every port_override block below is stale -- the factory reset
  # wiped all custom port names and most assignments, and none of this is reconciled
  # while ignore_changes is on. See docs/unifi-manual-vs-tofu.md 3.2-3.4 for the
  # live-vs-code table. Also note `forward = "disabled"` never disabled a port: Port
  # State is port_security_enabled + an empty MAC allowlist (upstream PR #470).

  port_override {
    index           = 1
    name            = "Servacho-Gosho"
    op_mode         = "switch"
    forward         = "customize"
    port_profile_id = var.port_profile_private_servers_id
  }

  port_override {
    index    = 2
    name     = "SFP+ 2"
    op_mode  = "switch"
    forward  = "disabled"
    poe_mode = "off"
  }

  port_override {
    index    = 3
    name     = "SFP+ 3"
    op_mode  = "switch"
    forward  = "disabled"
    poe_mode = "off"
  }

  port_override {
    index    = 4
    name     = "SFP+ 4"
    op_mode  = "switch"
    forward  = "disabled"
    poe_mode = "off"
  }

  port_override {
    index    = 5
    name     = "SFP+ 5"
    op_mode  = "switch"
    forward  = "disabled"
    poe_mode = "off"
  }

  port_override {
    index    = 6
    name     = "SFP+ 6"
    op_mode  = "switch"
    forward  = "disabled"
    poe_mode = "off"
  }

  port_override {
    index    = 7
    name     = "SFP+ 7"
    op_mode  = "switch"
    forward  = "disabled"
    poe_mode = "off"
  }

  port_override {
    index           = 8
    name            = "UDM-Pro-Max"
    op_mode         = "switch"
    forward         = "customize"
    port_profile_id = var.port_profile_unifi_devices_id
  }
}
