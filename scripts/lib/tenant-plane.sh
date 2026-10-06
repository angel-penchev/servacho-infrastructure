# shellcheck shell=bash
# Shared by the scripts that act on the organisations' management planes from
# the root plane: the root OpenBao, SSH to a plane, and curl. Sourced after
# `set -euo pipefail`; needs BAO (the bao binary) and the root OpenBao's
# address and token as BAO_ADDR / BAO_TOKEN or VAULT_ADDR / VAULT_TOKEN.

export BAO_ADDR="${BAO_ADDR:-${VAULT_ADDR:?root OpenBao address}}"
export BAO_TOKEN="${BAO_TOKEN:-${VAULT_TOKEN:?root OpenBao token}}"
: "${BAO:?path to the bao binary}"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
(
  umask 077
  "$BAO" kv get -mount=secret -field=private_key management-plane/ssh >"$work/key"
)

# Runs the script on stdin on a plane, as root, against its local OpenBao.
on_plane() {
  ssh -i "$work/key" -o BatchMode=yes -o ConnectTimeout=10 \
    -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR \
    "root@$1" 'BAO_ADDR=http://127.0.0.1:8200 bash -s'
}

# curl, from this repository's flake when the runner has none on its path.
curl() {
  if type -P curl >/dev/null; then
    command curl "$@"
  else
    nix --extra-experimental-features 'nix-command flakes' shell \
      "$(realpath "$(dirname "${BASH_SOURCE[0]}")/../../nixos")#curl" --command curl "$@"
  fi
}
