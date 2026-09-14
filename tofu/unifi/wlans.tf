# FIXME(unifi): every WLAN ignores passphrase, wlan_bands and wlan_band -- the
#   provider reads them back in a different shape (redacted passphrase, reordered
#   bands) and would otherwise fail with "inconsistent result after apply".

data "unifi_ap_group" "default" {
  name = "All APs"
}

data "unifi_client_qos_rate" "default" {
  name = "Default"
}

# 802.1X against the site RADIUS server; users in radius.tf.
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

  group_rekey = 0 # live: GTK rekey disabled on every SSID (provider default 3600)

  lifecycle {
    ignore_changes = [passphrase, wlan_bands, wlan_band]
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

  # Must stay declared. The attribute is Optional+Computed with a false default
  # (provider wlan_resource.go:469), so leaving it out makes an apply switch Client
  # Device Isolation OFF on the guest SSID without showing a diff. Live is on.
  l2_isolation = true

  group_rekey = 0 # live: GTK rekey disabled on every SSID (provider default 3600)

  lifecycle {
    ignore_changes = [passphrase, wlan_bands, wlan_band]
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

  group_rekey = 0 # live: GTK rekey disabled on every SSID (provider default 3600)

  lifecycle {
    ignore_changes = [passphrase, wlan_bands, wlan_band]
  }
}

# 2.4 GHz-only, WPA2, no PMF: for IoT devices that cannot do WPA3 or 5 GHz.
resource "unifi_wlan" "stkr_iot_2_4ghz" {
  name       = "StKr_IoT_2.4GHz"
  security   = "wpapsk"
  passphrase = var.wlan_iot_passphrase
  network_id = unifi_network.iot.id

  wlan_bands    = ["2g"]
  ap_group_ids  = [data.unifi_ap_group.default.id]
  user_group_id = data.unifi_client_qos_rate.default.id

  wpa3_support    = false
  wpa3_transition = false
  pmf_mode        = "disabled"
  bss_transition  = true

  is_guest  = false
  hide_ssid = true

  group_rekey = 0     # live: GTK rekey disabled on every SSID (provider default 3600)
  no2ghz_oui  = false # live: 2.4 GHz-only clients are not steered away (default true)

  lifecycle {
    ignore_changes = [passphrase, wlan_bands, wlan_band]
  }
}
