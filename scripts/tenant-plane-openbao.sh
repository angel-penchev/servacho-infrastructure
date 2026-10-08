#!/usr/bin/env bash
# The OpenBao of the tenant management planes, driven from the root plane.
#
#   bootstrap   Once per plane, from tofu/organisation/plane.tf after the
#               install: initialise the plane's OpenBao, keep its unseal keys
#               and root token in the root OpenBao at
#               secret/management-planes/<tenant> before anything uses them,
#               unseal it, and copy the tenant's Proxmox token and the plane's
#               deploy key from the root OpenBao into the plane's secret/proxmox
#               and secret/deploy-key. The tenant's pipeline then provisions
#               with that token and never sees the root one.
#               Safe to run again: an initialised plane is unsealed and reseeded.
#               Needs TENANT, TARGET_HOST, PROXMOX_TOKEN_SECRET and
#               DEPLOY_KEY_SECRET.
#
#   unseal-all  From the workflows, after the root OpenBao is unsealed: unseal
#               every plane recorded under secret/management-planes, the way
#               the openbao-unseal action does for the root plane. A plane that
#               cannot be reached is reported and skipped, so one tenant's
#               outage never fails the root pipeline.
#
# Both need BAO (the bao binary) and the root OpenBao's address and token, as
# BAO_ADDR / BAO_TOKEN or VAULT_ADDR / VAULT_TOKEN. SSH to the planes uses the
# deploy key from the root OpenBao's secret/management-plane/ssh. No secret is
# put on a command line, here or on the plane.
set -euo pipefail

# shellcheck source=lib/tenant-plane.sh
source "$(dirname "$(realpath "$0")")/lib/tenant-plane.sh"

# The plane's seal status as JSON; empty if it cannot be reached.
plane_status() {
  echo 'bao status -format=json || true' | on_plane "$1" 2>/dev/null || true
}

# Unseals a plane with the threshold of keys from its record. The keys travel
# inside the script on stdin, into curl's stdin on the plane.
unseal() {
  local host=$1 record=$2
  jq -r '.unseal_keys_b64[0:.unseal_threshold][]' <<<"$record" |
    while read -r key; do
      printf "curl -sf -X PUT --data @- http://127.0.0.1:8200/v1/sys/unseal >/dev/null <<'JSON'\n%s\nJSON\n" \
        "$(jq -nc --arg key "$key" '{key: $key}')"
    done |
    on_plane "$host"
  [[ $(plane_status "$host" | jq -r .sealed) == false ]]
}

# The plane's OpenBao may be initialised without its keys reaching the root
# OpenBao. A new plane holds nothing yet, so starting it over is the way out.
lost_keys() {
  echo "The OpenBao on $TARGET_HOST may be initialised with keys nobody has. If it" >&2
  echo "holds nothing yet: stop openbao there, empty /var/lib/openbao, start it, and" >&2
  echo "run this again (tofu apply -replace on its terraform_data)." >&2
}

bootstrap() {
  : "${TENANT:?}" "${TARGET_HOST:?}" "${PROXMOX_TOKEN_SECRET:?}" "${DEPLOY_KEY_SECRET:?}"
  local path="management-planes/$TENANT" state init record token deploy_key

  # OpenBao starts with the system; give it a few minutes after the switch.
  for _ in $(seq 36); do
    state=$(plane_status "$TARGET_HOST")
    jq -e 'has("initialized")' <<<"$state" >/dev/null 2>&1 && break
    sleep 5
  done
  if ! jq -e 'has("initialized")' <<<"$state" >/dev/null 2>&1; then
    echo "OpenBao on $TARGET_HOST did not answer" >&2
    return 1
  fi

  if [[ $(jq -r .initialized <<<"$state") == false ]]; then
    echo "Initialising OpenBao on $TARGET_HOST"
    # The record first: without it the plane's OpenBao can never be unsealed.
    if ! init=$(echo 'bao operator init -key-shares=5 -key-threshold=3 -format=json' | on_plane "$TARGET_HOST") ||
      ! jq -e '(.root_token | length > 0) and ((.unseal_keys_b64 | length) >= .unseal_threshold)' <<<"$init" >/dev/null 2>&1; then
      lost_keys
      return 1
    fi
    for attempt in 1 2 3; do
      if jq --arg address "$TARGET_HOST" '. + {address: $address}' <<<"$init" |
        "$BAO" kv put -mount=secret "$path" - >/dev/null; then
        break
      fi
      if [[ $attempt == 3 ]]; then
        lost_keys
        return 1
      fi
      sleep 5
    done
  elif ! "$BAO" kv get -mount=secret "$path" >/dev/null 2>&1; then
    echo "OpenBao on $TARGET_HOST is initialised, but secret/$path is not in the root OpenBao." >&2
    lost_keys
    return 1
  fi

  record=$("$BAO" kv get -mount=secret -format=json "$path" | jq .data.data)
  if [[ $(plane_status "$TARGET_HOST" | jq -r .sealed) == true ]]; then
    unseal "$TARGET_HOST" "$record" || {
      echo "OpenBao on $TARGET_HOST is still sealed" >&2
      return 1
    }
  fi

  token=$("$BAO" kv get -mount=secret -field=api_token "$PROXMOX_TOKEN_SECRET")
  deploy_key=$("$BAO" kv get -mount=secret -format=json "$DEPLOY_KEY_SECRET" |
    jq -c '.data.data | {private_key, public_key}')
  on_plane "$TARGET_HOST" <<EOF
set -euo pipefail
export BAO_TOKEN=$(printf %q "$(jq -r .root_token <<<"$record")")
bao secrets list -format=json | jq -e 'has("secret/")' >/dev/null ||
  bao secrets enable -path=secret kv-v2 >/dev/null
printf '%s' $(printf %q "$token") | bao kv put -mount=secret proxmox api_token=- >/dev/null
printf '%s' $(printf %q "$deploy_key") | bao kv put -mount=secret deploy-key - >/dev/null
EOF
  echo "OpenBao on $TARGET_HOST: unsealed, record at secret/$path, Proxmox token at its secret/proxmox, deploy key at its secret/deploy-key"
}

unseal_all() {
  local tenants tenant record host status
  tenants=$("$BAO" kv list -mount=secret -format=json management-planes 2>/dev/null | jq -r '.[]' || true)
  if [[ -z $tenants ]]; then
    echo "No tenant management planes recorded."
    return 0
  fi
  for tenant in $tenants; do
    tenant=${tenant%/}
    if ! record=$("$BAO" kv get -mount=secret -format=json "management-planes/$tenant" | jq -e .data.data) ||
      ! host=$(jq -er .address <<<"$record"); then
      echo "::warning::could not read secret/management-planes/$tenant from the root OpenBao"
      continue
    fi
    status=$(plane_status "$host")
    case $(jq -r .sealed <<<"$status" 2>/dev/null) in
      false) echo "$tenant ($host): unsealed" ;;
      true)
        if unseal "$host" "$record"; then
          echo "$tenant ($host): unsealed now"
        else
          echo "::warning::$tenant management plane ($host) is still sealed"
        fi
        ;;
      *) echo "::warning::$tenant management plane ($host) did not answer" ;;
    esac
  done
}

case "${1:-}" in
  bootstrap) bootstrap ;;
  unseal-all) unseal_all ;;
  *)
    echo "usage: $0 bootstrap|unseal-all" >&2
    exit 2
    ;;
esac
