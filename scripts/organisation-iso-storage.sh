#!/usr/bin/env bash
# An organisation's own ISO storage on the Proxmox node: a directory storage
# for ISO images only, where the organisation's token may upload and delete
# its installer without reaching anything else (tofu/organisation/main.tf).
# The pinned bpg/proxmox has no storage resource, so this creates it through
# the Proxmox API with the root token; Proxmox makes the directory.
#
#   create   Creates STORAGE at STORAGE_PATH, or checks that the one there is
#            a directory storage at that path holding ISO images only.
#   destroy  Removes the storage definition. The files stay on the node.
#
# Needs PROXMOX_ENDPOINT, STORAGE and STORAGE_PATH, and the root OpenBao's
# address and token as BAO_ADDR / BAO_TOKEN or VAULT_ADDR / VAULT_TOKEN; the
# root Proxmox token is read from its secret/proxmox. No token is put on a
# command line.
set -euo pipefail

# The runner has no curl of its own; take it from this repository's flake.
if ! command -v curl >/dev/null 2>&1; then
  exec nix --extra-experimental-features 'nix-command flakes' shell \
    "$(realpath "$(dirname "$0")/../nixos")#curl" --command "$0" "$@"
fi

: "${PROXMOX_ENDPOINT:?}" "${STORAGE:?}" "${STORAGE_PATH:?}"
bao_addr="${BAO_ADDR:-${VAULT_ADDR:?root OpenBao address}}"
bao_token="${BAO_TOKEN:-${VAULT_TOKEN:?root OpenBao token}}"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
umask 077
printf 'X-Vault-Token: %s\n' "$bao_token" >"$work/bao"
if ! pve_token=$(curl -sf -H @"$work/bao" "$bao_addr/v1/secret/data/proxmox" | jq -er .data.data.api_token); then
  echo "Could not read the root Proxmox token from secret/proxmox in the root OpenBao" >&2
  exit 1
fi
printf 'Authorization: PVEAPIToken=%s\n' "$pve_token" >"$work/pve"

# A Proxmox API call; prints the response body, or on an HTTP error reports
# it on stderr and fails.
pve() {
  local method=$1 path=$2 body
  shift 2
  if ! body=$(curl -sk --fail-with-body -H @"$work/pve" -X "$method" "${PROXMOX_ENDPOINT%/}/api2/json$path" "$@"); then
    echo "Proxmox API: $method $path failed: ${body:-no response}" >&2
    return 1
  fi
  printf '%s\n' "$body"
}

create() {
  local current
  if current=$(pve GET "/storage/$STORAGE" 2>/dev/null); then
    if ! jq -e --arg path "$STORAGE_PATH" \
      '.data | .type == "dir" and .path == $path and .content == "iso"' <<<"$current" >/dev/null; then
      echo "Storage $STORAGE exists but is not a directory storage at $STORAGE_PATH for ISO images only:" >&2
      jq -c .data <<<"$current" >&2
      return 1
    fi
    echo "Storage $STORAGE: already there"
    return 0
  fi
  pve POST /storage \
    --data-urlencode "storage=$STORAGE" \
    --data-urlencode type=dir \
    --data-urlencode "path=$STORAGE_PATH" \
    --data-urlencode content=iso \
    --data-urlencode create-base-path=1 \
    --data-urlencode create-subdirs=1 >/dev/null
  echo "Storage $STORAGE: created at $STORAGE_PATH"
}

destroy() {
  if pve GET "/storage/$STORAGE" >/dev/null 2>&1; then
    pve DELETE "/storage/$STORAGE" >/dev/null
    echo "Storage $STORAGE: removed; its files stay in $STORAGE_PATH"
  else
    echo "Storage $STORAGE: not there"
  fi
}

case "${1:-}" in
  create) create ;;
  destroy) destroy ;;
  *)
    echo "usage: $0 create|destroy" >&2
    exit 2
    ;;
esac
