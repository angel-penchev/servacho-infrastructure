locals {
  unifi_country_codes = {
    "Bulgaria" = 100
  }
}

# Site settings the provider can express. Every block mirrors `/get/setting`.
resource "unifi_setting" "default" {
  site = "default"

  # IGMP snooping is off on every network; network_ids = [] is declared so a network
  # ticked in the UI shows up in the plan.
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
    auto_upgrade = {
      enabled = true
      hour    = 3 # the "weekly, Sunday" part is UniFi OS-only, see below
    }
    debug_tools_enabled = false
    unifi_idp_enabled   = true
    wifiman_enabled     = true
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
  #   (Wired / Wireless Networks support) -- have no attribute at v0.65.0; both are on,
  #   set by hand, and a radius write never sends them.
  radius = {
    secret             = var.radius_profile_secret
    auth_port          = 1812
    acct_port          = 1813
    accounting_enabled = false
  }

  # Settings -> Networks -> Global Switch Settings. A write sends only the keys declared
  # here, so the hand-set keys below survive it. Device Isolation
  # (acl_device_isolation, a list of network ids) is left undeclared: it is read from
  # the controller and never sent.
  # FIXME(unifi): set by hand, no attribute at v0.65.0: 802.1X Fallback VLAN = Guest
  #   (`dot1x_fallback_networkconf_id`; load-bearing, see port_profiles.tf), the RADIUS
  #   profile 802.1X uses (`radiusprofile_id`; a RADIUS profile is bound), L3 Network
  #   Isolation (ACL) off (`acl_l3_isolation`), Flow Control off (`flowctrl_enabled`),
  #   and Auto STP Edge Detection off (`auto_stp_edge_detection_enabled`).
  global_switch = {
    stp_version            = "rstp"
    jumboframe_enabled     = false
    dhcp_snoop             = true # Rogue DHCP Server Detection
    dot1x_portctrl_enabled = true # 802.1X Control; load-bearing for Host Device ports
  }
}

# Control Plane -> Console, the rest of the page: UniFi OS console settings or Network
# `locale` / `super_*` settings (go-unifi models the latter; `unifi_setting` has no block
# for any of them at v0.65.0), plus Direct Remote Connection and SSH. Live values:
# FIXME(unifi): Name "UDM StKr" -- the console name (the Network device name is in
#   device_udm_pro_max.tf).
# FIXME(unifi): Location / Time Zone -- `locale.timezone = "Europe/Sofia"`; country IS
#   managed above.
# FIXME(unifi): Night Mode 10:00 PM - 8:00 AM -- not in `unifi_setting.lcm`;
#   `unifi_device.lcm.night_mode` would carry it only if the UDM's device record holds
#   the console's schedule (unchecked).
# FIXME(unifi): Email Services = UI Mail Server -- `super_mail.provider = "cloud"`.
# FIXME(unifi): Analytics & Improvements = Off -- `super_mgmt.enable_analytics = false`.
# FIXME(unifi): Support File = Full, Certificates = none -- UniFi OS console settings;
#   Remote Access = on -- `super_cloudaccess.enabled`. Direct Remote Connection = off and
#   SSH = off stay undeclared on purpose (see the mgmt block above): they map to
#   `mgmt.direct_connect_enabled` and, unchecked, `mgmt.ssh.enabled`.
# FIXME(unifi): Updates: "weekly, Sunday 4 AM" -- only `mgmt.auto_upgrade.hour = 3`
#   reaches the Network app; weekday and update channels are UniFi OS only.
# FIXME(unifi): Backups: auto backup on, `super_mgmt.autobackup_cron_expr "30 0 1 * *"`
#   (monthly), timezone Europe/Sofia, keep 0 days.

# FIXME(unifi): Default Security Posture = Allow All
#   (`global_network.default_security_posture = "ALLOW_ALL"`) -- no attribute, no
#   resource and no go-unifi type at v0.65.0.

# Etherlighting is unmanaged on purpose: live runs the controller default colours
# (docs/unifi-manual-vs-tofu.md §11). To manage it, set the colours in the UI first, then
# declare `etherlighting` on unifi_setting.default with both speed_overrides and
# network_overrides exactly as stored: a declared list replaces the controller's.
