data "unifi_ap_group" "default" {
  name = "All APs"
}

data "unifi_client_qos_rate" "default" {
  name = "Default"
}

resource "unifi_wlan" "stkr" {
  name       = "StKr"
  security   = "wpaeap"
  network_id = unifi_network.main.id

  wlan_bands    = ["2g", "5g", "6g"]
  ap_group_ids  = [data.unifi_ap_group.default.id]
  user_group_id = data.unifi_client_qos_rate.default.id

  radius_profile_id = data.unifi_radius_profile.default.id

  wpa3_support    = true
  wpa3_transition = true
  pmf_mode        = "optional"
  bss_transition  = true

  is_guest = false
  # FIXME(unifi): The provider often returns different structures for passphrase 
  # (redacted vs unredacted) and wlan_bands than what is defined in state.
  # We must ignore these to prevent "inconsistent result after apply" crashes.
  lifecycle {
    ignore_changes = [passphrase, wlan_bands]
  }
}

resource "unifi_wlan" "stkr_guest" {
  name       = "StKr_Guest"
  security   = "wpapsk"
  passphrase = var.wlan_guest_passphrase
  network_id = unifi_network.guest.id

  wlan_bands    = ["2g", "5g", "6g"]
  ap_group_ids  = [data.unifi_ap_group.default.id]
  user_group_id = data.unifi_client_qos_rate.default.id

  wpa3_support    = true
  wpa3_transition = true
  pmf_mode        = "optional"
  bss_transition  = true

  is_guest = true
  # FIXME(unifi): The provider often returns different structures for passphrase 
  # (redacted vs unredacted) and wlan_bands than what is defined in state.
  # We must ignore these to prevent "inconsistent result after apply" crashes.
  lifecycle {
    ignore_changes = [passphrase, wlan_bands]
  }
}

resource "unifi_wlan" "stkr_iot" {
  name       = "StKr_IoT"
  security   = "wpapsk"
  passphrase = var.wlan_iot_passphrase
  network_id = unifi_network.iot.id

  wlan_bands    = ["2g", "5g", "6g"]
  ap_group_ids  = [data.unifi_ap_group.default.id]
  user_group_id = data.unifi_client_qos_rate.default.id

  wpa3_support    = true
  wpa3_transition = true
  pmf_mode        = "optional"
  bss_transition  = true

  is_guest  = false
  hide_ssid = true
  # FIXME(unifi): The provider often returns different structures for passphrase 
  # (redacted vs unredacted) and wlan_bands than what is defined in state.
  # We must ignore these to prevent "inconsistent result after apply" crashes.
  lifecycle {
    ignore_changes = [passphrase, wlan_bands]
  }
}
