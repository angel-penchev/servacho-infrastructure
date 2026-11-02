# Gateway mDNS Proxy (Settings -> Networks -> Global), managed as the `mdns` block of
# unifi_setting.default in settings.tf. Change it in the UI first, then mirror it there.
#
# Main + IoT only: phones on Main discover TVs, speakers and smart-home gear on IoT.
# Guest discovers nothing; servers and tenant VPS networks are out.
#
# Casting, media and smart-home discovery plus Apple File Sharing / iTunes between
# Macs. Excluded on purpose: apple_iChat, ftp_servers, ssh_servers, time_capsule,
# web_servers, windows_file_sharing_samba -- remote-access services are not for
# discovery.
#
# Service identifiers = the UI checkbox ids (mixed case is real). Full catalogue, 25:
#   amazon_devices  android_tv_remote  apple_airDrop  apple_airPlay  apple_file_sharing
#   apple_iChat  apple_iTunes  aqara  bose  dns_service_discovery  ftp_servers
#   google_chromecast  homeKit  matter_network  philips_hue  printers  roku  scanners
#   shelly  sonos  spotify_connect  ssh_servers  time_capsule  web_servers
#   windows_file_sharing_samba
