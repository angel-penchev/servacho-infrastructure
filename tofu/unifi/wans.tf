resource "unifi_wan" "vivacom-primary" {
  name         = "Vivacom Primary"
  networkgroup = "WAN"
  type         = "dhcp"
  type_v6      = "disabled"

  load_balance = {
    failover_priority = 1
    type              = "weighted"
    weight            = 50
  }

  provider_capabilities = {
    download_kilobits_per_second = 600000
    upload_kilobits_per_second   = 400000
  }
}

resource "unifi_wan" "vivacom-secondary" {
  name         = "Vivacom Secondary"
  networkgroup = "WAN2"
  type         = "dhcp"
  type_v6      = "disabled"

  load_balance = {
    failover_priority = 2
    type              = "failover-only"
    weight            = 50
  }

  provider_capabilities = {
    download_kilobits_per_second = 150000
    upload_kilobits_per_second   = 40000
  }
}
