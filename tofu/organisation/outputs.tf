output "pool_id" {
  value = proxmox_virtual_environment_pool.this.id
}

output "proxmox_token_secret" {
  description = "Where the root OpenBao keeps the organisation's Proxmox token."
  value       = vault_kv_secret_v2.proxmox_token.name
}
