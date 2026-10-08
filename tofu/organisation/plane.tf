# The organisation's management plane: a VM in its pool on its VLAN, holding
# its OpenTofu state, its OpenBao and, later, the runner for its infrastructure
# repository (docs/tenant-management-planes.md). From an empty VM to an
# unsealed OpenBao with nothing run by hand:
#
#   1. infrastructure-reusables' nixos-vm boots the installer, nixos-anywhere
#      installs the plane's host from ../nixos, and the plane comes up on its
#      static .15 address, deployed like the root plane from then on;
#   2. scripts/tenant-plane-openbao.sh initialises its OpenBao, keeps the keys
#      in the root OpenBao and seeds it with this organisation's Proxmox token.

module "plane" {
  count  = var.plane == null ? 0 : 1
  source = "github.com/angel-penchev/infrastructure-reusables//tofu/modules/nixos-vm?ref=v0.5.0"

  name             = var.plane.host
  node_name        = var.node_name
  vm_id            = var.plane.vm_id
  pool_id          = proxmox_virtual_environment_pool.this.id
  tags             = ["nixos", "management-plane", var.id]
  vlan_id          = var.vlan
  cores            = var.plane.cores
  memory           = var.plane.memory
  installer_iso_id = var.installer_iso_id
  flake            = var.nixos_flake
  host             = var.plane.host
  address          = var.plane.address
  ssh_private_key  = var.ssh_private_key
}

# The key the plane installs and deploys its organisation's VMs with. The
# private half goes to the plane's OpenBao (secret/deploy-key) through the
# root OpenBao; the public half is the organisation's to commit, for its
# installer and its hosts (the root output organisation_deploy_keys).
resource "tls_private_key" "plane_deploy" {
  count = var.plane == null ? 0 : 1

  algorithm = "ED25519"
}

resource "vault_kv_secret_v2" "plane_deploy_key" {
  count = var.plane == null ? 0 : 1

  mount = "secret"
  name  = "deploy-keys/${var.id}"
  data_json = jsonencode({
    private_key = tls_private_key.plane_deploy[0].private_key_openssh
    public_key  = trimspace(tls_private_key.plane_deploy[0].public_key_openssh)
  })
}

# Once per installation, and again whenever the organisation's Proxmox token
# or the plane's deploy key changes, so the plane's copies follow them (the
# bootstrap is safe to repeat).
# The root OpenBao's address and token come from the workflow's environment,
# as for the vault provider.
resource "terraform_data" "openbao" {
  count = var.plane == null ? 0 : 1

  triggers_replace = [
    module.plane[0].installation_id,
    sha256(proxmox_virtual_environment_user_token.tofu.value),
    sha256(tls_private_key.plane_deploy[0].public_key_openssh),
  ]

  provisioner "local-exec" {
    command = "${abspath("${path.module}/../../scripts/tenant-plane-openbao.sh")} bootstrap"
    environment = {
      BAO                  = var.openbao_cli
      TENANT               = var.id
      TARGET_HOST          = var.plane.address
      PROXMOX_TOKEN_SECRET = vault_kv_secret_v2.proxmox_token.name
      DEPLOY_KEY_SECRET    = vault_kv_secret_v2.plane_deploy_key[0].name
    }
  }

  depends_on = [module.plane]
}

# The plane's GitHub Actions runner, as its host file in ../nixos sets it up.
data "external" "runner" {
  count = var.plane == null ? 0 : 1

  program = [
    "nix",
    "--extra-experimental-features",
    "nix-command flakes",
    "eval",
    "--json",
    "${var.nixos_flake}#nixosConfigurations.${var.plane.host}.config.servacho.managementPlane.runner",
    "--apply",
    "r: { enable = if r.enable then \"true\" else \"false\"; url = if r.enable then r.url else \"\"; name = r.name; token_file = r.tokenFile; }",
  ]
}

# Registers the runner once the deploy has enabled it, with a registration
# token minted from the organisation's GitHub token in the root OpenBao
# (secret/github/runners/<id>); again for a new installation or repository.
resource "terraform_data" "runner" {
  count = var.plane != null && try(data.external.runner[0].result.enable, "false") == "true" ? 1 : 0

  triggers_replace = [
    module.plane[0].installation_id,
    data.external.runner[0].result.url,
    data.external.runner[0].result.name,
  ]

  provisioner "local-exec" {
    command = abspath("${path.module}/../../scripts/tenant-plane-runner.sh")
    environment = {
      BAO                 = var.openbao_cli
      TARGET_HOST         = var.plane.address
      RUNNER_URL          = data.external.runner[0].result.url
      RUNNER_NAME         = data.external.runner[0].result.name
      TOKEN_FILE          = data.external.runner[0].result.token_file
      GITHUB_TOKEN_SECRET = "github/runners/${var.id}"
    }
  }

  depends_on = [module.plane]
}
