# Alarm Manager (notifications). Documentation only.
#
# FIXME(unifi): alarms are UniFi OS alarm-service objects (`/api/v2/alarms/network`,
#   `/api/v2/alarms/profiles`), outside the Network API, and the provider has no
#   alarm/notification resource. Live, verified 2026-09-14: 17 rules, all controller
#   defaults from first boot (2026-09-05), none custom, no profiles. Every rule: action
#   Notify -> all admins, When to Send "Always", scope include-all; admin preference
#   push on, email off. Because these are defaults, a factory reset reproduces them;
#   any custom alarm added later must be listed here.
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
#   Power       UPS Power State                trigger event_type "on-battery", site + all UPS
#   System      UniFi Device Disconnected      site + all devices
