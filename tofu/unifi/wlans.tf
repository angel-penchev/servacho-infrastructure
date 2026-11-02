# FIXME(unifi): every WLAN keeps passphrase in ignore_changes until a plan without it
#   is clean. Refresh copies the controller's x_passphrase into state; whether the
#   tofu account gets it in clear or masked is unchecked. If in clear, that plan
#   compares OpenBao with live on the three PSK SSIDs (both IoT SSIDs read
#   var.wlan_iot_passphrase, so their live keys must match too): no diff means OpenBao
#   holds the live keys, and a `~ passphrase` must not be applied, since it would PUT
#   OpenBao's key over the live one. A diff that never clears means a masked key: move
#   to passphrase_wo instead. StKr declares no passphrase and may show a one-time
#   `passphrase -> null`, which sends nothing.
#
# Change WLAN bands in the UI first, then mirror wlan_bands. The provider plans wlan_band
# from state but writes the value it derives from wlan_bands (2g with 5g: both; 2g
# alone: 2g; 5g alone: 5g), so a code-first change of that value, such as dual-band <->
# 2.4 GHz-only or dropping 5g, PUTs and then fails with "inconsistent result after
# apply". Adding or dropping only 6g is safe.

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
  ap_group      = { ids = [data.unifi_ap_group.default.id] }
  user_group_id = data.unifi_client_qos_rate.default.id

  radius = { profile_id = data.unifi_radius_profile.default.id }

  wpa3           = { support = true, transition = true }
  pmf_mode       = "optional"
  bss_transition = true

  is_guest = false

  group_rekey = 0 # live: GTK rekey disabled on every SSID

  lifecycle {
    ignore_changes = [passphrase]
  }
}

resource "unifi_wlan" "stkr_guest" {
  name       = "StKr_Guest"
  security   = "wpapsk"
  passphrase = var.wlan_guest_passphrase
  network_id = unifi_network.guest.id

  wlan_bands    = ["2g", "5g", "6g"]
  ap_group      = { ids = [data.unifi_ap_group.default.id] }
  user_group_id = data.unifi_client_qos_rate.default.id

  wpa3           = { support = true, transition = true }
  pmf_mode       = "optional"
  bss_transition = true

  is_guest = true

  # Must stay declared: a create sends false when it is unset, so a rebuilt guest SSID
  # would come up with Client Device Isolation off. Live is on.
  l2_isolation = true

  group_rekey = 0 # live: GTK rekey disabled on every SSID

  lifecycle {
    ignore_changes = [passphrase]
  }
}

resource "unifi_wlan" "stkr_iot" {
  name       = "StKr_IoT"
  security   = "wpapsk"
  passphrase = var.wlan_iot_passphrase
  network_id = unifi_network.iot.id

  wlan_bands    = ["2g", "5g", "6g"]
  ap_group      = { ids = [data.unifi_ap_group.default.id] }
  user_group_id = data.unifi_client_qos_rate.default.id

  wpa3           = { support = true, transition = true }
  pmf_mode       = "optional"
  bss_transition = true

  is_guest  = false
  hide_ssid = true

  group_rekey = 0 # live: GTK rekey disabled on every SSID

  lifecycle {
    ignore_changes = [passphrase]
  }
}

# 2.4 GHz-only, WPA2, no PMF: for IoT devices that cannot do WPA3 or 5 GHz.
resource "unifi_wlan" "stkr_iot_2_4ghz" {
  name       = "StKr_IoT_2.4GHz"
  security   = "wpapsk"
  passphrase = var.wlan_iot_passphrase
  network_id = unifi_network.iot.id

  wlan_bands    = ["2g"]
  ap_group      = { ids = [data.unifi_ap_group.default.id] }
  user_group_id = data.unifi_client_qos_rate.default.id

  wpa3           = { support = false, transition = false }
  pmf_mode       = "disabled"
  bss_transition = true

  is_guest  = false
  hide_ssid = true

  group_rekey = 0     # live: GTK rekey disabled on every SSID
  no2ghz_oui  = false # live: 2.4 GHz-only clients are not steered away

  lifecycle {
    ignore_changes = [passphrase]
  }
}
