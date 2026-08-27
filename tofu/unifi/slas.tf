# ----------------------------------------------------------------------------
# WAN SLA Configuration
# ----------------------------------------------------------------------------
# Note: As of v0.55.0, the ubiquiti-community/unifi provider does not yet have 
# a native `unifi_wan_sla` resource. 
#
# Since you're already digging into the provider source code for your PR, 
# I have mocked up exactly what the Terraform HCL design should look like 
# once you (or the community) add it to the provider.
#
# I am leaving this commented out for now so it doesn't break your `tofu apply`.
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
