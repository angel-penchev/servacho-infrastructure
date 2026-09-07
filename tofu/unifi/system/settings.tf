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

  # Site RADIUS server. Backs both the StKr WLAN (wpaeap) and wired 802.1X.
  #
  # NOTE: the schema exposes only the secret/ports/accounting. The two toggles that
  # actually turn the service on -- `enabled` and `configure_whole_network` (the
  # "Wired Networks" / "Wireless Networks" support switches) -- have no attribute at
  # v0.55.0 and stay manual. Both are already on. Checked 2026-09-08.
  radius = {
    secret             = var.radius_profile_secret
    auth_port          = 1812
    acct_port          = 1813
    accounting_enabled = false
  }
}

# ----------------------------------------------------------------------------
# Global Switch Settings & Security Posture
# ----------------------------------------------------------------------------
# Note (re-checked 2026-09-08, provider v0.55.0): `unifi_setting` still exposes no
# switch/dot1x block -- its attributes are auto_speedtest, country, doh, dpi,
# igmp_snooping, ips, lcm, mgmt, network_optimization, ntp, radius, syslog, usg.
# There is no `unifi_setting_switch` or `unifi_setting_security` resource either, so
# the block below remains aspirational.
#
# Two things in here are live and load-bearing, set by hand:
#   - dot1x_portctrl_enabled = true
#   - dot1x_fallback_networkconf_id = Guest -- REQUIRED for the "Host Device" port
#     profile to work at all. Without it an unauthenticated client on a dot1x_ctrl
#     = "auto" port is simply blocked and never gets a DHCP lease.
#     See ../core/port_profiles.tf and docs/unifi-browser-changes.md.
#
# Also note upstream #476: even per-device stp_version/stp_priority are dropped from
# the update PUT, so STP is unmanageable from either direction right now.
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
    fallback_vlan_id  = var.network_guest_id # currently set by hand in the UI
  }
}

resource "unifi_setting_security" "posture" {
  site = "default"

  default_security_posture = "allow_all"
}
*/
