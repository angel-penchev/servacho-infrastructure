data "unifi_ap_group" "default" {
  name = "All APs"
}

resource "unifi_wlan" "stkr" {
  name       = "StKr"
  security   = "wpaeap"
  network_id = unifi_network.main.id

  wlan_bands   = ["2g", "5g", "6g"]
  ap_group_ids = [data.unifi_ap_group.default.id]

  radius_profile_id = unifi_radius_profile.default.id

  wpa3_support    = true
  wpa3_transition = true
  pmf_mode        = "optional"

  is_guest = false
}

resource "unifi_wlan" "stkr_guest" {
  name       = "StKr_Guest"
  security   = "wpapsk"
  passphrase = var.wlan_guest_passphrase
  network_id = unifi_network.guest.id

  wlan_bands   = ["2g", "5g", "6g"]
  ap_group_ids = [data.unifi_ap_group.default.id]

  wpa3_support    = true
  wpa3_transition = true
  pmf_mode        = "optional"

  is_guest = true
}

resource "unifi_wlan" "stkr_iot" {
  name       = "StKr_IoT"
  security   = "wpapsk"
  passphrase = var.wlan_iot_passphrase
  network_id = unifi_network.iot.id

  wlan_bands   = ["2g", "5g", "6g"]
  ap_group_ids = [data.unifi_ap_group.default.id]

  wpa3_support    = true
  wpa3_transition = true
  pmf_mode        = "optional"

  is_guest = false
}
