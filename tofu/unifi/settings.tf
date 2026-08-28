locals {
  unifi_country_codes = {
    "Bulgaria" = 100
  }
}

resource "unifi_setting" "default" {
  site = "default"

  # Manages the site-wide settings that the provider supports.
  igmp_snooping = {
    enabled = false
  }

  auto_speedtest = {
    enabled   = true
    cron_expr = "0 4 * * *"
  }

  country = {
    code = local.unifi_country_codes["Bulgaria"]
  }

  ntp = {
    setting_preference = "auto"
  }
}

# ----------------------------------------------------------------------------
# Global Switch Settings & Security Posture
# ----------------------------------------------------------------------------
# Note: As of v0.55.0, the ubiquiti-community/unifi provider does not natively 
# support the new UniFi Global Switch Settings and Default Security Posture.
# ----------------------------------------------------------------------------
/*
resource "unifi_setting_switch" "global" {
  site = "default"

  spanning_tree               = "rstp"
  jumbo_frames                = false
  rogue_dhcp_server_detection = true
  
  l3_network_isolation = false
  device_isolation     = false

  dot1x_control {
    enabled           = true
    credential_source = "local"
    fallback_vlan_id  = unifi_network.guest.id
  }
}

resource "unifi_setting_security" "posture" {
  site = "default"

  default_security_posture = "allow_all"
}
*/
