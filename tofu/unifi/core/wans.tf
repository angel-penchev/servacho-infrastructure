resource "unifi_wan" "vivacom_primary" {
  name         = "Vivacom Primary"
  networkgroup = "WAN"
  type         = "dhcp"
  type_v6      = "disabled"

  load_balance = {
    failover_priority = 1
    type              = "weighted"
    weight            = 99
  }

  provider_capabilities = {
    download_kilobits_per_second = 600000
    upload_kilobits_per_second   = 400000
  }
}

resource "unifi_wan" "vivacom_secondary" {
  name         = "Vivacom Secondary"
  networkgroup = "WAN2"
  type         = "dhcp"
  type_v6      = "disabled"

  # No weight: the controller stores none for a failover-only uplink.
  load_balance = {
    failover_priority = 2
    type              = "failover-only"
  }

  # No provider_capabilities: none are configured on the controller for WAN2.
}
