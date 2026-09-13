resource "unifi_device" "u7_pro_living_room" {
  mac               = "9c:05:d6:d9:ad:79"
  name              = "Living Room U7-Pro"
  forget_on_destroy = false
  disabled          = false

  # LED off, per the rebuild checklist. Upstream #337 (LED updates dropped from the
  # update PUT) was fixed in v0.54.0, so unlike config_network this one does apply.
  led_override = "off"

  # Management moved to UniFi Devices (VLAN 99) on 2026-09-13, runbook Phase 1. This
  # attribute IS in the v0.55.0 minimal update PUT, unlike config_network below.
  mgmt_network_id = var.network_unifi_devices_id

  # Matches live exactly (verified 2026-09-13 after the VLAN 99 move). NOTE: at v0.55.0 the provider drops
  # config_network from the update PUT (buildMinimalUpdateDevice, upstream PR #463),
  # so this block is read-only in practice: because live already has these values the
  # plan is a no-op, but CHANGING the address here would not reach the controller and
  # the apply would fail with "inconsistent result after apply". Change the management
  # IP in the UI first, then mirror it here, until #463 ships.
  # https://github.com/ubiquiti-community/terraform-provider-unifi/pull/463
  config_network = {
    type    = "static"
    ip      = "192.168.99.4"
    netmask = "255.255.255.0"
    gateway = "192.168.99.1"
    dns1    = "192.168.99.1"
  }

  # Precautionary. The AP is adopted and online; `disabled` is another field the
  # v0.55.0 update PUT drops, and the controller does not report it at all for APs,
  # so a null-vs-false mismatch could surface as "inconsistent result after apply".
  # Live matches code today; drop this ignore after v0.56.0 and see.
  lifecycle {
    ignore_changes = [disabled]
  }
}
