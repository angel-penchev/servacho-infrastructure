resource "unifi_device" "usw_aggregation" {
  mac               = "1c:6a:1b:98:38:ee"
  name              = "USW Aggregation"
  forget_on_destroy = false
  disabled          = false

  port_override {
    index           = 1
    name            = "SFP+ 1"
    port_profile_id = var.port_profile_private_servers_id
    op_mode         = "switch"
  }

  # TODO: double check this and open a PR for ubiquiti-community/unifi
  lifecycle {
    ignore_changes = [port_override]
  }
}
