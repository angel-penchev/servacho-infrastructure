resource "unifi_device" "usw_pro_max_24_poe" {
  mac                = "9c:05:d6:e2:6b:1d"
  name               = "USW Pro Max 24 PoE"
  forget_on_destroy  = false
  disabled           = false
  flowctrl_enabled   = false
  jumboframe_enabled = false
  # FIXME(unifi): `config_network` is populated by modelToAPIDevice but dropped by
  # buildMinimalUpdateDevice, so at v0.55.0 it is only honoured on create/adopt --
  # an update silently discards it and the apply fails with "inconsistent result
  # after apply". Declared here so the code states the intended reality; it will not
  # take effect until upstream PR #463 ships (checked 2026-09-08).
  # https://github.com/ubiquiti-community/terraform-provider-unifi/pull/463
  config_network = {
    type    = "static"
    ip      = "192.168.1.2"
    netmask = "255.255.255.0"
    gateway = "192.168.1.1"
    dns1    = "192.168.1.1"
  }

  # ----------------------------------------------------------------------------
  # Note: As of v0.55.0, the ubiquiti-community/unifi provider does not yet have 
  # support for the ether_lighting block on devices or site settings. 
  #
  # PR in progress: https://github.com/ubiquiti-community/terraform-provider-unifi/pull/463
  # ----------------------------------------------------------------------------
  /*
  # Once merged, the following can be added to the resource below:
  #  ether_lighting {
  # mode       = "speed"
  # brightness = 100
  # behavior   = "steady"
  # led_mode   = "etherlighting"
  #  }
  */

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
    name            = "LR-01"
    op_mode         = "switch"
    forward         = "customize"
    port_profile_id = var.port_profile_host_device_id
  }

  port_override {
    index           = 2
    name            = "LR-02"
    op_mode         = "switch"
    forward         = "customize"
    port_profile_id = var.port_profile_host_device_id
  }

  port_override {
    index           = 3
    name            = "LR-03"
    op_mode         = "switch"
    forward         = "customize"
    port_profile_id = var.port_profile_host_device_id
  }

  port_override {
    index           = 4
    name            = "LR-04"
    op_mode         = "switch"
    forward         = "customize"
    port_profile_id = var.port_profile_host_device_id
  }

  port_override {
    index           = 5
    name            = "LR-05"
    op_mode         = "switch"
    forward         = "customize"
    port_profile_id = var.port_profile_host_device_id
  }

  port_override {
    index           = 6
    name            = "LR-06"
    op_mode         = "switch"
    forward         = "customize"
    port_profile_id = var.port_profile_iot_id
  }

  port_override {
    index           = 7
    name            = "Balc-01"
    op_mode         = "switch"
    forward         = "customize"
    port_profile_id = var.port_profile_host_device_id
  }

  port_override {
    index           = 8
    name            = "Balc-02"
    op_mode         = "switch"
    forward         = "customize"
    port_profile_id = var.port_profile_host_device_id
  }

  port_override {
    index    = 9
    name     = "Port 9"
    op_mode  = "switch"
    forward  = "disabled"
    poe_mode = "off"
  }

  port_override {
    index    = 10
    name     = "Port 10"
    op_mode  = "switch"
    forward  = "disabled"
    poe_mode = "off"
  }

  port_override {
    index    = 11
    name     = "Port 11"
    op_mode  = "switch"
    forward  = "disabled"
    poe_mode = "off"
  }

  port_override {
    index           = 12
    name            = "Servacho-Gosho-JetKVM"
    op_mode         = "switch"
    forward         = "customize"
    port_profile_id = var.port_profile_private_servers_id
  }

  port_override {
    index           = 13
    name            = "K-01"
    op_mode         = "switch"
    forward         = "customize"
    port_profile_id = var.port_profile_host_device_id
  }

  port_override {
    index           = 14
    name            = "K-02"
    op_mode         = "switch"
    forward         = "customize"
    port_profile_id = var.port_profile_host_device_id
  }

  port_override {
    index           = 15
    name            = "BR-07"
    op_mode         = "switch"
    forward         = "customize"
    port_profile_id = var.port_profile_host_device_id
  }

  port_override {
    index           = 16
    name            = "BR-08"
    op_mode         = "switch"
    forward         = "customize"
    port_profile_id = var.port_profile_host_device_id
  }

  port_override {
    index           = 17
    name            = "BR-01"
    op_mode         = "switch"
    forward         = "customize"
    port_profile_id = var.port_profile_host_device_id
  }

  # Third JetKVM (`jetkvm-ce4ac3437e0d935d`, 30:52:53:0d:1a:68), fixed IP 192.168.5.23.
  # Was an inline native VLAN of Public Servers, which was wrong twice over: a JetKVM is
  # infrastructure and belongs on Private Servers alongside the `.20` / `.21` siblings, and
  # the live port carried `Host Device`, whose dot1x_ctrl = "auto" fallback-dumped the
  # supplicant-less device onto Guest with no usable address at all.
  #
  # Applied on the controller 2026-09-09: port 18 now carries the `Private Server`
  # profile and the JetKVM picked up 192.168.5.23. This block only records intent either
  # way, because ignore_changes above means no apply pushes it.
  port_override {
    index           = 18
    name            = "BR-02"
    op_mode         = "switch"
    forward         = "customize"
    port_profile_id = var.port_profile_private_servers_id
  }

  port_override {
    index           = 19
    name            = "BR-03"
    op_mode         = "switch"
    forward         = "customize"
    port_profile_id = var.port_profile_host_device_id
  }

  port_override {
    index           = 20
    name            = "BR-04"
    op_mode         = "switch"
    forward         = "customize"
    port_profile_id = var.port_profile_public_servers_id
  }

  port_override {
    index           = 21
    name            = "BR-05"
    op_mode         = "switch"
    forward         = "customize"
    port_profile_id = var.port_profile_host_device_id
  }

  port_override {
    index           = 22
    name            = "BR-06"
    op_mode         = "switch"
    forward         = "customize"
    port_profile_id = var.port_profile_host_device_id
  }

  port_override {
    index           = 23
    name            = "LR-WiFi"
    op_mode         = "switch"
    forward         = "customize"
    port_profile_id = var.port_profile_unifi_devices_id
  }

  port_override {
    index           = 24
    name            = "BR-WiFi"
    op_mode         = "switch"
    forward         = "customize"
    port_profile_id = var.port_profile_unifi_devices_id
  }

  port_override {
    index   = 25
    name    = "SFP+ 1"
    op_mode = "switch"
    forward = "customize"
  }

  port_override {
    index           = 26
    name            = "UDM-Pro-Max"
    op_mode         = "switch"
    forward         = "customize"
    port_profile_id = var.port_profile_unifi_devices_id
  }
}
