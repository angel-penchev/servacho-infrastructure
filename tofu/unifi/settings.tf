locals {
  unifi_country_codes = {
    "Bulgaria" = 100
  }
}

# Site settings the provider can express. Every block mirrors `/get/setting`.
# FIXME(unifi): `unifi_setting` ImportState stores only the id, so the first plan after an
#   import shows every block as an add and the apply re-POSTs values that are already live
#   (harmless while they match: the RADIUS secret and passphrases come from OpenBao and
#   must equal the controller's). Upstream: read the site settings on import.
resource "unifi_setting" "default" {
  site = "default"

  # FIXME(unifi): network_ids is declared empty on purpose -- the provider returns [] after
  #   the write while a null plan value aborts the apply with "inconsistent result".
  igmp_snooping = {
    enabled     = false
    network_ids = []
  }

  # Daily at 04:00.
  auto_speedtest = {
    enabled   = true
    cron_expr = "0 4 * * *"
  }

  country = {
    code = local.unifi_country_codes["Bulgaria"]
  }

  # Auto = the four ubnt pool servers, computed.
  ntp = {
    setting_preference = "auto"
  }

  # Control Plane -> Console / Updates. SSH and Direct Remote Connection are off and
  # absent from the record, so they stay undeclared (null vs false would be a
  # permanent diff).
  mgmt = {
    advanced_feature_enabled = true
    auto_upgrade             = true
    auto_upgrade_hour        = 3 # the "weekly, Sunday" part is UniFi OS-only, see below
    debug_tools_enabled      = false
    unifi_idp_enabled        = true
    wifiman_enabled          = true
  }

  # Control Plane -> Console -> LED / Screen.
  lcm = {
    enabled      = true
    brightness   = 80
    idle_timeout = 300
    sync         = true
    touch_event  = true
  }

  # Site RADIUS server behind the StKr WLAN and wired 802.1X.
  # FIXME(unifi): the toggles that turn it on -- `enabled` and `configure_whole_network`
  #   (Wired / Wireless Networks support) -- have no attribute at v0.55.0; both are on,
  #   set by hand.
  radius = {
    secret             = var.radius_profile_secret
    auth_port          = 1812
    acct_port          = 1813
    accounting_enabled = false
  }
}

# Control Plane -> Console, the rest of the page: UniFi OS console
# settings or Network `super_*` settings, none with a `unifi_setting` block. Live values:
# FIXME(unifi): Name "UDM StKr" -- the console name (the Network device name is in
#   device_udm_pro_max.tf).
# FIXME(unifi): Location / Time Zone -- `locale.timezone = "Europe/Sofia"`; country IS
#   managed above.
# FIXME(unifi): Night Mode 10:00 PM - 8:00 AM -- UniFi OS only, not even in `lcm`.
# FIXME(unifi): Email Services = UI Mail Server -- `super_mail.provider = "cloud"`.
# FIXME(unifi): Analytics & Improvements = Off -- `super_mgmt.enable_analytics = false`.
# FIXME(unifi): Support File = Full, Certificates = none, Remote Access = on, Direct
#   Remote Connection = off, SSH = off -- UniFi OS console settings.
# FIXME(unifi): Updates: "weekly, Sunday 4 AM" -- only `mgmt.auto_upgrade_hour = 3`
#   reaches the Network app; weekday and update channels are UniFi OS only.
# FIXME(unifi): Backups: auto backup on, `super_mgmt.autobackup_cron_expr "30 0 1 * *"`
#   (monthly), timezone Europe/Sofia, keep 0 days.

# FIXME(unifi): `unifi_setting` has no switch/dot1x block at v0.55.0 and there is no
#   `unifi_setting_switch` / `unifi_setting_security` resource; the blocks below are
#   aspirational. Two values in them are live and load-bearing, set by hand:
#   dot1x_portctrl_enabled = true and dot1x_fallback_networkconf_id = Guest -- without
#   the fallback an unauthenticated client on a Host Device port never gets DHCP
#   (port_profiles.tf). Upstream #476 also drops per-device stp_version/stp_priority
#   from the update PUT, so STP is unmanageable from either side.
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

# FIXME(unifi): no `unifi_setting_ether_lighting` resource and no device-level
#   `ether_lighting` block at v0.55.0 (upstream PR #463). Live runs the controller
#   default colours, NOT the ones below (docs/unifi-manual-vs-tofu.md 11) -- if the
#   resource lands, decide first whether to keep these or mirror the defaults.
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
