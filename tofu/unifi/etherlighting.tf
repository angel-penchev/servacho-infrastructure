# ----------------------------------------------------------------------------
# Site-Wide Etherlighting Configuration
# ----------------------------------------------------------------------------
# Note: As of v0.55.0, the ubiquiti-community/unifi provider does not yet have 
# a native `unifi_setting_ether_lighting` resource. 
#
# PR in progress: https://github.com/ubiquiti-community/terraform-provider-unifi/pull/463
# ----------------------------------------------------------------------------

/*
resource "unifi_setting_ether_lighting" "site_colors" {
  site = "default"

  speed_override {
    speed = "FE"
    color = "#ff0509"
  }

  speed_override {
    speed = "GbE"
    color = "#FFCC00"
  }

  speed_override {
    speed = "2.5GbE"
    color = "#05ff19"
  }

  speed_override {
    speed = "10GbE"
    color = "#054aff"
  }
}
*/
