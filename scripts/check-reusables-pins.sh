#!/usr/bin/env bash
# infrastructure-reusables is pinned twice: by the NixOS flake (nixos/flake.lock)
# and by every OpenTofu module source (?ref=), which cannot take a variable.
# Fails when they name different tags, so the NixOS modules and the OpenTofu
# modules that install them always come from the same release.
set -euo pipefail
cd "$(dirname "$0")/.."

flake=$(jq -r .nodes.reusables.original.ref nixos/flake.lock)
status=0
while IFS=: read -r file line ref; do
  if [[ $ref != "$flake" ]]; then
    echo "::error file=$file,line=$line::infrastructure-reusables $ref here, $flake in nixos/flake.lock"
    status=1
  fi
done < <(grep -rnoP --include='*.tf' 'infrastructure-reusables//[^"?]*\?ref=\K[^"]+' tofu)

if [[ $status == 0 ]]; then
  echo "infrastructure-reusables: $flake everywhere"
fi
exit $status
