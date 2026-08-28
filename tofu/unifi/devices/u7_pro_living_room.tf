resource "unifi_device" "u7_pro_living_room" {
  mac               = "9c:05:d6:d9:ad:79"
  name              = "Living Room U7-Pro"
  forget_on_destroy = false
  disabled          = false

  # FIXME(unifi): The U7-Pro AP is currently physically offline or unadopted.
  # The UniFi controller forcibly returns disabled=true for offline APs, causing
  # provider schema crashes. Remove this ignore_changes block once it is plugged in.
  lifecycle {
    ignore_changes = [disabled]
  }
}
