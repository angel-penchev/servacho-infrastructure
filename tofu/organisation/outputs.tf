output "id" {
  value = var.id
}

output "pool_id" {
  value = proxmox_virtual_environment_pool.this.id
}

output "proxmox_token_secret" {
  description = "Where the root OpenBao keeps the organisation's Proxmox token."
  value       = vault_kv_secret_v2.proxmox_token.name
}

output "iso_storage" {
  description = "The organisation's own storage for ISO images."
  value       = terraform_data.iso_storage.output.storage
}

output "deploy_public_key" {
  description = "Public half of the plane's deploy key; null without a plane."
  value       = try(trimspace(tls_private_key.plane_deploy[0].public_key_openssh), null)
}
