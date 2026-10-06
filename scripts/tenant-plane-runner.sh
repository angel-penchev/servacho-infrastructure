#!/usr/bin/env bash
# Registers an organisation's plane's GitHub Actions runner, from the root
# plane, after the deploy that enabled it (tofu/organisation/plane.tf).
#
# The runner needs a registration token once: it registers on its first start
# and keeps its own credentials from then on. The token is minted here with
# the organisation's GitHub token from the root OpenBao and lives an hour; the
# GitHub token itself never reaches the plane. A plane whose runner has
# registered with RUNNER_URL already is left alone.
#
# Needs TARGET_HOST, RUNNER_URL (a repository or an organisation),
# RUNNER_NAME, TOKEN_FILE (the runner's tokenFile) and GITHUB_TOKEN_SECRET
# (the root OpenBao's path holding `token`, a GitHub token that may manage
# that repository's or organisation's self-hosted runners), plus what
# lib/tenant-plane.sh needs.
set -euo pipefail

# shellcheck source=lib/tenant-plane.sh
source "$(dirname "$(realpath "$0")")/lib/tenant-plane.sh"

: "${TARGET_HOST:?}" "${RUNNER_URL:?}" "${RUNNER_NAME:?}" "${TOKEN_FILE:?}" "${GITHUB_TOKEN_SECRET:?}"
state="/var/lib/github-runner/$RUNNER_NAME"
unit="github-runner-$RUNNER_NAME.service"

# .runner is the runner's own JSON, written with a byte order mark.
registered=$(echo "sed '1s/^\xEF\xBB\xBF//' $(printf %q "$state/.runner") 2>/dev/null | jq -r .gitHubUrl 2>/dev/null || true" |
  on_plane "$TARGET_HOST")
if [[ $registered == "$RUNNER_URL" ]]; then
  echo "Runner $RUNNER_NAME on $TARGET_HOST: registered with $RUNNER_URL already"
  exit 0
fi

case $RUNNER_URL in
  https://github.com/*/*) api="repos/${RUNNER_URL#https://github.com/}" ;;
  https://github.com/*) api="orgs/${RUNNER_URL#https://github.com/}" ;;
  *)
    echo "RUNNER_URL must be https://github.com/<owner>[/<repository>], not $RUNNER_URL" >&2
    exit 1
    ;;
esac

(
  umask 077
  if ! github_token=$("$BAO" kv get -mount=secret -field=token "$GITHUB_TOKEN_SECRET" 2>/dev/null); then
    echo "No GitHub token at secret/$GITHUB_TOKEN_SECRET in the root OpenBao." >&2
    echo "Put one there that may manage $RUNNER_URL's self-hosted runners (docs/tenant-management-planes.md)." >&2
    exit 1
  fi
  printf 'Authorization: Bearer %s\n' "$github_token" >"$work/github"
)
if ! response=$(curl -s --fail-with-body -X POST -H @"$work/github" \
  -H 'Accept: application/vnd.github+json' -H 'X-GitHub-Api-Version: 2022-11-28' \
  "${GITHUB_API:-https://api.github.com}/$api/actions/runners/registration-token"); then
  echo "GitHub refused a registration token for $RUNNER_URL: $(jq -r '.message // .' <<<"$response" 2>/dev/null || echo "$response")" >&2
  exit 1
fi
token=$(jq -er .token <<<"$response")

echo "Registering runner $RUNNER_NAME on $TARGET_HOST with $RUNNER_URL"
on_plane "$TARGET_HOST" <<PLANE
set -euo pipefail
install -d -m 0755 $(printf %q "$(dirname "$TOKEN_FILE")")
(umask 077; printf '%s' $(printf %q "$token") >$(printf %q "$TOKEN_FILE"))
systemctl reset-failed $(printf %q "$unit") 2>/dev/null || true
systemctl restart $(printf %q "$unit")
for _ in \$(seq 60); do
  [[ -e $(printf %q "$state/.runner") ]] && exit 0
  sleep 2
done
echo "The runner did not register within two minutes:" >&2
journalctl -u $(printf %q "$unit") -n 30 --no-pager >&2
exit 1
PLANE
echo "Runner $RUNNER_NAME on $TARGET_HOST: registered with $RUNNER_URL"
