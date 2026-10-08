#!/usr/bin/env bash
# infrastructure-reusables is pinned three ways: by the NixOS flake
# (nixos/flake.lock), by every OpenTofu module source (?ref=) and by every
# GitHub Actions step that uses its actions (@ref), none of which can take a
# variable. Fails when they name different tags, so the NixOS modules, the
# OpenTofu modules that install them and the actions that run OpenTofu always
# come from the same release.
set -euo pipefail
cd "$(dirname "$0")/.."

flake=$(jq -r .nodes.reusables.original.ref nixos/flake.lock)
status=0
while IFS=: read -r file line ref; do
  if [[ $ref != "$flake" ]]; then
    echo "::error file=$file,line=$line::infrastructure-reusables $ref here, $flake in nixos/flake.lock"
    status=1
  fi
done < <(
  grep -rnoP --include='*.tf' 'infrastructure-reusables//[^"?]*\?ref=\K[^"]+' tofu
  grep -rnoP 'uses: *angel-penchev/infrastructure-reusables/[^@ ]*@\K[^ #]+' .github/workflows
)

if [[ $status == 0 ]]; then
  echo "infrastructure-reusables: $flake everywhere"
fi
exit $status
