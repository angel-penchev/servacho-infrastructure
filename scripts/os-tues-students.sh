#!/usr/bin/env bash
# Hands os-tues the class's roster and has it create the students' accounts,
# from the root plane (tofu/os_tues.tf): ROSTER, the JSON object of user name
# to initial password hash from the root OpenBao, becomes
# /var/lib/os-tues/students.json, and the host's os-tues-students service
# does the rest (nixos/hosts/os-tues.nix, docs/os-tues.md).
#
# Needs TARGET_HOST, SSH_PRIVATE_KEY (the deploy key root there accepts) and
# ROSTER.
set -euo pipefail

: "${TARGET_HOST:?}" "${SSH_PRIVATE_KEY:?}" "${ROSTER:?}"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
(
  umask 077
  printf '%s\n' "$SSH_PRIVATE_KEY" >"$work/key"
)

# The roster through stdin, so it never reaches a command line.
ssh -i "$work/key" -o BatchMode=yes -o ConnectTimeout=10 \
  -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR \
  "root@$TARGET_HOST" '
    set -euo pipefail
    install -d -m 0700 /var/lib/os-tues
    umask 077
    cat >/var/lib/os-tues/students.json.new
    mv /var/lib/os-tues/students.json.new /var/lib/os-tues/students.json
    systemctl start os-tues-students.service
  ' <<<"$ROSTER"
