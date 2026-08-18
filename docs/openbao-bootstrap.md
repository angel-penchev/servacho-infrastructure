# OpenBao bootstrap (no SSO)

The management-plane OpenBao instance listens only on `127.0.0.1:8200`. It
does not need an SSO auth method: the GitHub Actions runner authenticates with a
dedicated, least-privileged token stored in the `OPENBAO_TOFU_TOKEN` repository
secret. Do not use the initial root token in the workflow.

## First deployment

1. Deploy [the management-plane configuration](../nixos/hosts/servacho-managment-plane/configuration.nix) and verify that the `openbao` service is running.
2. On the management VM, initialize and unseal OpenBao. Store every unseal key
   and the initial root token outside this repository.

   ```sh
   export BAO_ADDR=http://127.0.0.1:8200
   bao operator init -key-shares=5 -key-threshold=3
   bao operator unseal
   bao operator unseal
   bao operator unseal
   bao login
   ```

3. Enable KV v2 storage and store the existing Proxmox API token. Enter the
   token at the prompt; never place it in a shell history or committed file.

   ```sh
   bao secrets enable -path=secret kv-v2
   read -s PROXMOX_API_TOKEN
   printf '\n'
   bao kv put secret/proxmox api_token="$PROXMOX_API_TOKEN"
   unset PROXMOX_API_TOKEN
   ```

4. Create the policy and a dedicated runner token. The token may read only this
   secret and may create the short-lived child token used by the Vault provider.

   ```sh
   cat >/tmp/openbao-tofu-policy.hcl <<'EOF'
   path "secret/data/proxmox" {
     capabilities = ["read"]
   }

   path "auth/token/create" {
     capabilities = ["update"]
   }
   EOF

   bao policy write opentofu-runner /tmp/openbao-tofu-policy.hcl
   bao token create -orphan -policy=opentofu-runner -ttl=8760h -display-name=opentofu-runner
   rm /tmp/openbao-tofu-policy.hcl
   ```

5. Save the generated token as the repository Actions secret
   `OPENBAO_TOFU_TOKEN`. The workflows set `VAULT_ADDR` and `VAULT_TOKEN`; the
   HashiCorp Vault provider uses OpenBao's compatible API to retrieve the
   Proxmox token.

## Operations

- Unseal OpenBao after every reboot with any three of the five unseal keys.
- Rotate the former hardcoded Proxmox token, update `secret/proxmox`, and revoke
  the old token. It was committed to Git before this migration and must be
  considered compromised.
- Rotate `OPENBAO_TOFU_TOKEN` before its one-year TTL expires. Revoke the old
  token after updating the repository secret.
- OpenTofu reads the Proxmox credential into its state and plan. The local state
  directory and plan artifacts must remain restricted to the runner; do not
  publish state files or plan artifacts.