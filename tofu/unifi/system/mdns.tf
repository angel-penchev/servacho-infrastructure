# ----------------------------------------------------------------------------
# mDNS Service Filtering Configuration
# ----------------------------------------------------------------------------
# Note: As of v0.55.0, the ubiquiti-community/unifi provider does not yet have 
# a native `unifi_setting_mdns` resource for granular mDNS service filtering.
# ----------------------------------------------------------------------------

/*
resource "unifi_setting_mdns" "gateway_proxy" {
  site = "default"

  mode = "custom"
  
  vlan_scope = [
    var.network_main_id,
    var.network_guest_id,
    var.network_iot_id
  ]
  
  service_scope = "specific"

  # The UI shows 17 selected services including Apple suite, Amazon, Android, etc.
  services = [
    "amazon_devices",
    "android_tv_remote",
    "apple_airdrop",
    "apple_airplay",
    "apple_file_sharing",
    "apple_ichat",
    "apple_itunes",
    # ... and 10 more
  ]
}
*/
