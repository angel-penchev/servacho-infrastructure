# ----------------------------------------------------------------------------
# Alarm Manager (Notifications)
#
# FIXME(unifi): not expressible at provider v0.55.0. Alarms live in the UniFi OS
# alarm service (`/api/v2/alarms/network`, `/api/v2/alarms/profiles`), not in the
# Network application API the provider talks to, and the provider has no
# alarm/notification resource at all (the only "alert" strings in the binary are
# per-WLAN `alert_enabled` and LLDP-MED `lldpmed_notify_enabled`). Documented here so
# the intent survives a rebuild; recreate by hand in Network -> Alarm Manager.
#
# Live, verified 2026-09-14: 17 rules, ALL the controller defaults created at first
# boot (2026-09-05T15:04:13Z), none user-created, no notification profiles.
# Every rule: action Notify -> receivers ALL_ITEMS (every admin), When to Send
# "Always", scope "include" everything; the admin's own channel preference is
# push = true, email = false on all 17 (UI: "Mobile Notification (17)").
#
#   Category    Rule                           Trigger (if different) / scope
#   System      DHCP Leases Exhausted          site
#   Internet    Data Limit                     site + all devices
#   System      Device Adoption                (no scope)
#   System      Fan Issue Detected             site + all devices
#   Power       Insufficient PoE Power         site + all PoE switches
#   Internet    Internet Disconnected          site
#   System      Meshing                        site + all devices
#   System      Modem Restarted                trigger "Device Restarted", site
#   System      Multiple Devices Restarted     site
#   System      Network Loop Detected          site
#   Monitoring  Port Anomalies                 site + all devices
#   System      Port Dropping Traffic          site + all devices
#   System      Port Transmission Errors       site + all devices
#   System      STP Port Blocked               site
#   System      Slow RADIUS Authentication     site
#   Power       UPS Power State                trigger data event_type "on-battery", site + all UPS
#   System      UniFi Device Disconnected      site + all devices
#
# Nothing here deviates from the defaults, so a factory reset reproduces it without
# manual work. Any custom alarm added later must be listed above.
# ----------------------------------------------------------------------------
