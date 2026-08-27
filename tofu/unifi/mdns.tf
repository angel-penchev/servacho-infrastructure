# ----------------------------------------------------------------------------
# mDNS Service Filtering Configuration
# ----------------------------------------------------------------------------
# Note: As of v0.55.0, the ubiquiti-community/unifi provider does not yet have 
# a native `unifi_setting_mdns` resource for granular mDNS service filtering.
#
# PR in progress: N/A
# ----------------------------------------------------------------------------

/*
resource "unifi_setting_mdns" "site_services" {
  site = "default"

  service {
    code      = "amazon_devices"
    name      = "Amazon devices"
    addresses = [
      "_amzn-wplay._tcp.local",
      "_amazonecho-remote._tcp",
      "_workstation._tcp.local"
    ]
  }

  service {
    code      = "apple_airPlay"
    name      = "Apple AirPlay"
    addresses = [
      "_companion-link._tcp.local",
      "_appletv-v2._tcp.local",
      "_raop._tcp.local",
      "_airplay._tcp.local"
    ]
  }

  service {
    code      = "google_chromecast"
    name      = "Google Chromecast"
    addresses = [
      "_googlecast._tcp.local",
      "_googlezone._tcp.local"
    ]
  }

  service {
    code      = "homeKit"
    name      = "HomeKit"
    addresses = [
      "_homekit._tcp.local",
      "_hap._tcp.local"
    ]
  }

  service {
    code      = "matter_network"
    name      = "Matter network"
    addresses = [
      "_matterd._udp",
      "_matter_gateway._tcp",
      "_matter._tcp",
      "_matterc._udp"
    ]
  }

  service {
    code      = "philips_hue"
    name      = "Philips Hue"
    addresses = [
      "_philipshue._tcp.local"
    ]
  }

  service {
    code      = "shelly"
    name      = "Shelly"
    addresses = [
      "_shelly._tcp.local"
    ]
  }

  service {
    code      = "sonos"
    name      = "Sonos"
    addresses = [
      "_sonos._tcp.local"
    ]
  }

  service {
    code      = "spotify_connect"
    name      = "Spotify Connect"
    addresses = [
      "_spotify-connect._tcp.local"
    ]
  }

  # Add other services like android_tv_remote, printers, scanners, etc. 
  # following the same schema block format.
}
*/
