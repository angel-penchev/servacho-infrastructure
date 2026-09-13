# The controller-managed RADIUS profile ("Default", use_usg_auth_server = true). Also
# looked up in security/ and wireless/; each module resolves it on its own.
data "unifi_radius_profile" "default" {
  name = "Default"
}
