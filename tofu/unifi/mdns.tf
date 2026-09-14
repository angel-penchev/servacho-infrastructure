# ----------------------------------------------------------------------------
# Gateway mDNS Proxy (Settings -> Networks -> Global -> Gateway mDNS Proxy)
# ----------------------------------------------------------------------------
# MANUAL RUNBOOK ITEM. As of v0.55.0 the ubiquiti-community/unifi provider has no
# `unifi_setting_mdns` resource and nothing upstream addresses it (checked 2026-09-08).
# The block below is the intended configuration, kept as HCL so it can be applied
# the day the provider grows the resource. Until then it is applied by hand via
# `POST /api/s/default/set/setting/mdns`, and the live value is the source of truth.
#
# Wire format (learned the hard way on 2026-09-13 -- guesses get api.err.InvalidPayload):
#   mode                    "all" (UI: Auto) | "off" | "custom"
#   enabled_for             "all" (UI: Service Scope = All) | "some" (UI: Specific)
#   enabled_for_network_ids [<networkconf _id>, ...]        -- the VLAN scope
#   predefined_services     [{"code": "<identifier>"}, ...]  -- objects, not strings
#   custom_services         []
# Read-modify-write the full object returned by GET /get/setting (key "mdns").
#
# Per-network `multicast_dns` flags in networks.tf are cosmetic on UniFi OS
# gateways (upstream #282); this site-wide setting is what is actually in force.
#
# Service identifiers below were read from the controller UI on 2026-09-13 (the
# checkbox ids are the API values -- note the mixed camelCase, e.g. apple_airPlay,
# homeKit). Full catalogue the controller offers, 25 entries:
#
#   amazon_devices              Amazon Devices
#   android_tv_remote           Android TV Remote
#   apple_airDrop               Apple AirDrop
#   apple_airPlay               Apple AirPlay
#   apple_file_sharing          Apple File Sharing
#   apple_iChat                 Apple iChat
#   apple_iTunes                Apple iTunes
#   aqara                       Aqara
#   bose                        Bose
#   dns_service_discovery       DNS Service Discovery
#   ftp_servers                 FTP Servers
#   google_chromecast           Google Chromecast
#   homeKit                     HomeKit
#   matter_network              Matter Network
#   philips_hue                 Philips Hue
#   printers                    Printers
#   roku                        Roku
#   scanners                    Scanners
#   shelly                      Shelly
#   sonos                       Sonos
#   spotify_connect             Spotify Connect
#   ssh_servers                 SSH Servers
#   time_capsule                Time Capsule
#   web_servers                 Web Servers
#   windows_file_sharing_samba  Windows File Sharing / Samba
# ----------------------------------------------------------------------------

/*
resource "unifi_setting_mdns" "gateway_proxy" {
  site = "default"

  # mode:"custom" on the wire.
  mode = "custom"

  # Main and IoT only (decided 2026-09-13): phones on Main discover the TVs,
  # speakers and smart-home gear on IoT. Guest is deliberately out -- guests do
  # not get to discover anything -- and service discovery never crosses into
  # UniFi Devices, Public/Private Servers or the tenant VPS networks.
  vlan_scope = [
    unifi_network.main.id,
    unifi_network.iot.id,
  ]

  # enabled_for:"some" on the wire.
  service_scope = "specific"

  # Casting, media, smart-home discovery, plus Apple File Sharing and iTunes
  # for sharing between Macs across Main/IoT (decided 2026-09-13). Deliberately
  # excluded: apple_iChat, ftp_servers, ssh_servers, time_capsule, web_servers,
  # windows_file_sharing_samba -- remote-access services are not for discovery.
  services = [
    "amazon_devices",
    "android_tv_remote",
    "apple_airDrop",
    "apple_airPlay",
    "apple_file_sharing",
    "apple_iTunes",
    "aqara",
    "bose",
    "dns_service_discovery",
    "google_chromecast",
    "homeKit",
    "matter_network",
    "philips_hue",
    "printers",
    "roku",
    "scanners",
    "shelly",
    "sonos",
    "spotify_connect",
  ]
}
*/
