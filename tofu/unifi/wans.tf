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

  # FIXME(unifi): the controller stores no `enabled` on WAN networks, so the import read
  #   false while the provider defaults to true. Ignored rather than "fixed": an update
  #   PUT to a WAN is the one write that can take the internet down.
  lifecycle {
    ignore_changes = [enabled]
  }
}

# Failover-only: the controller stores no weight and no provider_capabilities for it.
resource "unifi_wan" "vivacom_secondary" {
  name         = "Vivacom Secondary"
  networkgroup = "WAN2"
  type         = "dhcp"
  type_v6      = "disabled"

  load_balance = {
    failover_priority = 2
    type              = "failover-only"
  }

  lifecycle {
    ignore_changes = [enabled] # see vivacom_primary
  }
}

# FIXME(unifi): no `unifi_wan_sla` resource at v0.55.0 and nothing upstream. Intended
#   WAN SLA monitor (Settings -> Internet); live has none.
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
