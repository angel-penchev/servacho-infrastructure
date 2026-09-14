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


# ----------------------------------------------------------------------------
# WAN SLA monitoring (Settings -> Internet -> WAN SLA) -- aspirational.
# FIXME(unifi): no `unifi_wan_sla` resource at provider v0.55.0 and nothing upstream.
# The block is the intended configuration; live has no SLA configured (not checked
# since 2026-09-08).
# ----------------------------------------------------------------------------

/*
resource "unifi_wan_sla" "ping_dns_probe" {
  name                = "Ping and DNS probe"
  monitor_health_type = "ANY"

  monitor {
    type        = "ICMP"
    target      = "1.1.1.1"
    interval    = 2
    time_period = 15
    
    alert {
      latency_threshold = 1500
      loss_threshold    = 20
      threshold_policy  = "all"
    }
  }

  monitor {
    type        = "ICMP"
    target      = "8.8.8.8"
    interval    = 2
    time_period = 15
    
    alert {
      latency_threshold = 1500
      loss_threshold    = 20
      threshold_policy  = "any"
    }
  }
}
*/
