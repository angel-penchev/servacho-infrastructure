# Gateway mDNS Proxy (Settings -> Networks -> Global). Live matches the block below
# since 2026-09-13; the live value is the source of truth.
#
# FIXME(unifi): no `unifi_setting_mdns` resource at v0.55.0 and nothing upstream. The
#   block is kept as HCL for the day the provider grows one; until then apply by hand
#   with `POST /api/s/default/set/setting/mdns`, read-modify-write of the full object
#   from `GET /get/setting` (key "mdns"). Wire format:
#     mode                    "all" (UI: Auto) | "off" | "custom"
#     enabled_for             "all" (Service Scope: All) | "some" (Specific)
#     enabled_for_network_ids [<networkconf _id>, ...]
#     predefined_services     [{"code": "<identifier>"}, ...]  -- objects, not strings
#     custom_services         []
#   Per-network multicast_dns flags (networks.tf) are derived from this setting
#   (upstream #282).
#
# Service identifiers = the UI checkbox ids (mixed case is real). Full catalogue, 25:
#   amazon_devices  android_tv_remote  apple_airDrop  apple_airPlay  apple_file_sharing
#   apple_iChat  apple_iTunes  aqara  bose  dns_service_discovery  ftp_servers
#   google_chromecast  homeKit  matter_network  philips_hue  printers  roku  scanners
#   shelly  sonos  spotify_connect  ssh_servers  time_capsule  web_servers
#   windows_file_sharing_samba

/*
resource "unifi_setting_mdns" "gateway_proxy" {
  site = "default"

  mode = "custom"

  # Main + IoT only: phones on Main discover TVs, speakers and smart-home gear on IoT.
  # Guest discovers nothing; servers and tenant VPS networks are out.
  vlan_scope = [
    unifi_network.main.id,
    unifi_network.iot.id,
  ]

  service_scope = "specific"

  # Casting, media and smart-home discovery plus Apple File Sharing / iTunes between
  # Macs. Excluded on purpose: apple_iChat, ftp_servers, ssh_servers, time_capsule,
  # web_servers, windows_file_sharing_samba -- remote-access services are not for
  # discovery.
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
