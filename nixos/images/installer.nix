# The installer every organisation's plane starts from: infrastructure-reusables'
# installer ISO, letting the root plane in as root with its deploy key. OpenTofu
# boots a new plane's VM from it and nixos-anywhere installs the host
# (tofu/organisation/plane.tf).
{ ... }:
{
  servacho.installer.name = "servacho-installer";

  users.users.root.openssh.authorizedKeys.keyFiles = [
    ../hosts/servacho-managment-plane/deploy-key.pub
  ];

  nixpkgs.hostPlatform = "x86_64-linux";
}
