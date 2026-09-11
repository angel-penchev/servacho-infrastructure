data "unifi_ap_group" "default" {
  name = "All APs"
}

data "unifi_client_qos_rate" "default" {
  name = "Default"
}

resource "unifi_wlan" "stkr" {
  name       = "StKr"
  security   = "wpaeap"
  network_id = var.network_main_id

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
    ignore_changes = [passphrase, wlan_bands, wlan_band]
  }
}

resource "unifi_wlan" "stkr_guest" {
  name       = "StKr_Guest"
  security   = "wpapsk"
  passphrase = var.wlan_guest_passphrase
  network_id = var.network_guest_id

  wlan_bands    = ["2g", "5g", "6g"]
  ap_group_ids  = [data.unifi_ap_group.default.id]
  user_group_id = data.unifi_client_qos_rate.default.id

  wpa3_support    = true
  wpa3_transition = true
  pmf_mode        = "optional"
  bss_transition  = true

  # Guest isolation. Both of these were disturbed on 2026-09-11 while testing whether
  # Guest clients could cast to the IoT TVs; see ../security/firewall.tf for why that
  # was abandoned. The values here are the intended state.
  #
  # is_guest: live is currently **false**. Switching the WLAN's Application back to
  # Hotspot in the admin panel silently resets Security Protocol to Open and blanks the
  # passphrase, so it was left alone rather than risk an open guest SSID. An apply fixes
  # this safely where the UI cannot: the provider sends the whole WLAN object, including
  # security = "wpapsk" and this passphrase, so is_guest goes back to true without
  # touching authentication.
  is_guest = true

  # l2_isolation: Client Device Isolation. Was previously undeclared, which is a real
  # hazard -- the provider schema defaults it to false (booldefault.StaticBool(false) at
  # unifi/wlan_resource.go:469, Optional+Computed), so an apply would have silently
  # turned guest client isolation OFF on a WLAN where the controller has it on. Declared
  # explicitly now. It is deliberately true: it is what stops guest devices reaching each
  # other, and UniFi's own tooltip notes it also breaks Chromecast/AirPlay discovery,
  # which is the behaviour we want here.
  l2_isolation = true

  # FIXME(unifi): The provider often returns different structures for passphrase
  # (redacted vs unredacted) and wlan_bands than what is defined in state.
  # We must ignore these to prevent "inconsistent result after apply" crashes.
  lifecycle {
    ignore_changes = [passphrase, wlan_bands, wlan_band]
  }
}

resource "unifi_wlan" "stkr_iot" {
  name       = "StKr_IoT"
  security   = "wpapsk"
  passphrase = var.wlan_iot_passphrase
  network_id = var.network_iot_id

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
    ignore_changes = [passphrase, wlan_bands, wlan_band]
  }
}

resource "unifi_wlan" "stkr_iot_2_4ghz" {
  name       = "StKr_IoT_2.4GHz"
  security   = "wpapsk"
  passphrase = var.wlan_iot_passphrase
  network_id = var.network_iot_id

  wlan_bands    = ["2g"]
  ap_group_ids  = [data.unifi_ap_group.default.id]
  user_group_id = data.unifi_client_qos_rate.default.id

  wpa3_support    = false
  wpa3_transition = false
  pmf_mode        = "disabled"
  bss_transition  = true

  is_guest  = false
  hide_ssid = true

  lifecycle {
    ignore_changes = [passphrase, wlan_bands, wlan_band]
  }
}


