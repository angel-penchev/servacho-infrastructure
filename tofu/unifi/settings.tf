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

  # Daily at 04:00. Set live via `/set/setting/auto_speedtest` on 2026-09-13 to match
  # this block (the setting key did not exist before); read-back identical.
  auto_speedtest = {
    enabled   = true
    cron_expr = "0 4 * * *"
  }

  country = {
    code = local.unifi_country_codes["Bulgaria"]
  }

  # NTP: Auto == the four ubnt pool servers (0-3.ubnt.pool.ntp.org), computed.
  ntp = {
    setting_preference = "auto"
  }

  # Control Plane -> Console and Updates, mirrored from `/get/setting` key `mgmt`
  # (2026-09-13). Only the fields the controller actually stores are declared; SSH and
  # Direct Remote Connection are OFF in the UI and simply absent from the record, so
  # they are left undeclared rather than pinned to false (null vs false would be a
  # permanent plan diff).
  mgmt = {
    advanced_feature_enabled = true
    auto_upgrade             = true
    auto_upgrade_hour        = 3 # the "weekly, Sunday" part lives in UniFi OS, see FIXME below
    debug_tools_enabled      = false
    unifi_idp_enabled        = true
    wifiman_enabled          = true
  }

  # Control Plane -> Console -> LED / Screen (`/get/setting` key `lcm`, 2026-09-13):
  # Screen on, brightness 80 %, 5 min idle timeout, settings synced, touch enabled.
  lcm = {
    enabled      = true
    brightness   = 80
    idle_timeout = 300
    sync         = true
    touch_event  = true
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
# Control Plane -> Console: the rest of the page (audited 2026-09-13)
#
# Everything on that page not covered by `mgmt`/`lcm`/`country` above is either a
# UniFi OS console setting (outside the Network application the provider talks to)
# or a Network `super_*` setting with no `unifi_setting` block at v0.55.0. Live values:
# FIXME(unifi): Name "UDM StKr"            -- the console name; the Network device name
#   of the same box is managed in device_udm_pro_max.tf, the console name is not.
# FIXME(unifi): Location / Time Zone       -- `locale.timezone = "Europe/Sofia"`, no block.
#   Country = Bulgaria (100) IS managed above.
# FIXME(unifi): Night Mode 10:00 PM - 8:00 AM -- not even in the Network `lcm` record;
#   UniFi OS only.
# FIXME(unifi): Email Services = UI Mail Server -- `super_mail.provider = "cloud"`.
# FIXME(unifi): Analytics & Improvements = Off -- `super_mgmt.enable_analytics = false`.
# FIXME(unifi): Support File = Full, Certificates = none, Remote Access = on,
#   Direct Remote Connection = off, SSH = off -- UniFi OS console settings (the two
#   last ones also surface as absent `mgmt.direct_connect_enabled` / `mgmt.ssh_enabled`).
# FIXME(unifi): Updates tab: auto-update on, "weekly, Sunday 4 AM" -- only
#   `mgmt.auto_upgrade_hour = 3` reaches the Network app (managed above); the weekday
#   and the UniFi OS/application update channels are UniFi OS only.
# FIXME(unifi): Backups tab: auto backup on, `super_mgmt.autobackup_cron_expr
#   "30 0 1 * *"` (monthly), timezone Europe/Sofia, keep 0 days -- no block.
# ----------------------------------------------------------------------------

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
#     See port_profiles.tf and docs/unifi-browser-changes.md.
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
    fallback_vlan_id  = unifi_network.guest.id # currently set by hand in the UI
  }
}

resource "unifi_setting_security" "posture" {
  site = "default"

  default_security_posture = "allow_all"
}
*/


# ----------------------------------------------------------------------------
# Etherlighting (Settings -> System -> Advanced) -- aspirational.
# FIXME(unifi): no `unifi_setting_ether_lighting` resource at provider v0.55.0
# (upstream PR #463 in progress). Live runs the controller default colours, which are
# NOT the ones below (see docs/unifi-manual-vs-tofu.md 11); if the resource lands,
# decide first whether to keep these colours or mirror the defaults.
# ----------------------------------------------------------------------------

/*
resource "unifi_setting_ether_lighting" "site_colors" {
  site = "default"

  speed_override {
    speed = "FE"
    color = "#ff0509"
  }

  speed_override {
    speed = "GbE"
    color = "#FFCC00"
  }

  speed_override {
    speed = "2.5GbE"
    color = "#05ff19"
  }

  speed_override {
    speed = "10GbE"
    color = "#054aff"
  }
}
*/
