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

  # Guest isolation. Both were disturbed on 2026-09-11 while testing Guest access to the
  # IoT TVs; see ../security/firewall.tf. These are the intended values.
  #
  # is_guest is currently false live: switching Application back to Hotspot in the admin
  # panel silently resets Security Protocol to Open and blanks the passphrase, so it was
  # left alone rather than risk an open guest SSID. An apply fixes it safely, since the
  # provider sends the whole WLAN object including the passphrase.
  is_guest = true

  # l2_isolation must stay declared: it is Optional+Computed with a false default
  # (wlan_resource.go:469), so leaving it out has an apply silently turn Client Device
  # Isolation off on a WLAN where the controller has it on.
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


