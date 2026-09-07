resource "unifi_device" "u7_pro_bedroom" {
  mac               = "9c:05:d6:d9:af:65"
  name              = "Bedroom U7-Pro"
  forget_on_destroy = false
  disabled          = false

  # LED off, per the rebuild checklist. Upstream #337 (LED updates dropped from the
  # update PUT) was fixed in v0.54.0, so unlike config_network this one does apply.
  led_override = "off"

  # FIXME(unifi): `config_network` is populated by modelToAPIDevice but dropped by
  # buildMinimalUpdateDevice, so at v0.55.0 it is only honoured on create/adopt --
  # an update silently discards it and the apply fails with "inconsistent result
  # after apply". Declared here so the code states the intended reality; it will not
  # take effect until upstream PR #463 ships (checked 2026-09-08).
  # https://github.com/ubiquiti-community/terraform-provider-unifi/pull/463
  config_network = {
    type    = "static"
    ip      = "192.168.1.5"
    netmask = "255.255.255.0"
    gateway = "192.168.1.1"
    dns1    = "192.168.1.1"
  }
}
