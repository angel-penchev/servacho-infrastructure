#!/usr/bin/env bash
# Runs os-tues-students on os-tues for .github/workflows/os-tues-students.yaml
# (docs/os-tues.md): imports the students in the sigma export SIGMA_EXPORT
# (base64, from the OS_TUES_SIGMA_EXPORT secret) into a class, or retires or
# restores a class. All the log gets is what the host prints: counts and
# column titles, no names.
#
# Needs ACTION (import, retire or restore) and CLASS; for import also
# SIGMA_EXPORT, MAX_STUDENTS and, possibly empty, GRADE. The deploy key comes
# from the root OpenBao at VAULT_ADDR with VAULT_TOKEN.
set -euo pipefail

: "${ACTION:?}" "${CLASS:?}" "${VAULT_ADDR:?}" "${VAULT_TOKEN:?}"
host=192.168.4.31
flake=$(realpath "$(dirname "$0")/../nixos")

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
(
  umask 077
  BAO_ADDR=$VAULT_ADDR BAO_TOKEN=$VAULT_TOKEN \
    nix --extra-experimental-features 'nix-command flakes' run "$flake#openbao" -- \
    kv get -mount=secret -field=private_key management-plane/ssh >"$work/key"
)

# The arguments become a command line on the host, so each is quoted for it;
# the host checks them again.
on_host() {
  local command=os-tues-students arg
  for arg in "$@"; do
    command+=" $(printf %q "$arg")"
  done
  ssh -i "$work/key" -o BatchMode=yes -o ConnectTimeout=10 \
    -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR \
    "root@$host" "$command"
}

case $ACTION in
  import)
    if [[ -z ${SIGMA_EXPORT:-} ]]; then
      echo "::error::No export: put sigma's in the secret first, base64 -w0 <export> | gh secret set OS_TUES_SIGMA_EXPORT" >&2
      exit 1
    fi
    base64 -d <<<"$SIGMA_EXPORT" >"$work/export"
    on_host import "$CLASS" --grade "${GRADE:-}" --max "${MAX_STUDENTS:?}" <"$work/export"
    echo "::notice::Imported. Delete the export from the repository's secrets: gh secret delete OS_TUES_SIGMA_EXPORT"
    ;;
  retire | restore)
    on_host "$ACTION" "$CLASS"
    ;;
  *)
    echo "::error::ACTION is import, retire or restore, not $ACTION" >&2
    exit 1
    ;;
esac
