# Leave `enabled` undeclared: state holds the false the import read, so declaring
# `enabled = true` would PUT it to both WANs, the one write that can take the
# internet down.

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

# Failover-only: the controller stores no provider_capabilities for it. The weight only
# counts under load balancing; Settings -> Internet writes 50 when it saves the WAN mode.
resource "unifi_wan" "vivacom_secondary" {
  name         = "Vivacom Secondary"
  networkgroup = "WAN2"
  type         = "dhcp"
  type_v6      = "disabled"

  load_balance = {
    failover_priority = 2
    type              = "failover-only"
    weight            = 50
  }
}

# FIXME(unifi): no `unifi_wan_sla` resource at v0.65.0, and `unifi_wan` has no attribute
#   for the SLA a WAN uses. Live has this one, set by hand, on both WANs (Settings ->
#   Internet; stored as `wan_sla` on each WAN). `unifi_wan` updates send only the keys
#   that change, so an apply leaves `wan_sla` alone.
#   ICMP only: an unpaid Vivacom line is a captive portal that answers DNS and drops
#   ICMP, so the Auto SLA (ping ping.ui.com, DNS via 1.1.1.1 and 8.8.8.8, down when two
#   fail) keeps it up. MAJORITY: down when two of the three targets fail; a target fails
#   on either threshold.
/*
resource "unifi_wan_sla" "icmp_probes" {
  name                = "ICMP Probes"
  monitor_health_type = "MAJORITY"

  monitor {
    type        = "ICMP"
    target      = "1.1.1.1"
    interval    = 5
    time_period = 60

    alert {
      latency_threshold = 1500
      loss_threshold    = 20
      threshold_policy  = "any"
    }
  }

  monitor {
    type        = "ICMP"
    target      = "8.8.8.8"
    interval    = 5
    time_period = 60

    alert {
      latency_threshold = 1500
      loss_threshold    = 20
      threshold_policy  = "any"
    }
  }

  monitor {
    type        = "ICMP"
    target      = "9.9.9.9"
    interval    = 5
    time_period = 60

    alert {
      latency_threshold = 1500
      loss_threshold    = 20
      threshold_policy  = "any"
    }
  }
}
*/
