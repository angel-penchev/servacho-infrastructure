#!/usr/bin/env bash
# This repository pins infrastructure-reusables in four places, and none of
# them can take a variable:
#   - the flake input in nixos/flake.nix
#   - its lock, nixos/flake.lock
#   - the ?ref= of each OpenTofu module source
#   - the @ref of each GitHub Actions step that uses its actions
# The script fails when they name different tags. Then the NixOS modules, the
# OpenTofu modules that install them and the actions that run OpenTofu come
# from one release. If the flake input names another tag than the lock, Nix
# locks the input again at build time, to the commit the tag then names. So
# the script checks the flake input too.
set -euo pipefail
cd "$(dirname "$0")/.."

flake=$(jq -r .nodes.reusables.original.ref nixos/flake.lock)

# The flake input can give the tag as a path (.../<tag>) or as ?ref=<tag>.
# The script fails if it finds neither. Otherwise a URL in another form
# skips the comparison, and the check passes.
input=$(grep -HnoP 'github:angel-penchev/infrastructure-reusables(/|\?ref=)\K[^"?/&]+' nixos/flake.nix) || {
  echo "::error file=nixos/flake.nix::no infrastructure-reusables input with a tag in the URL"
  exit 1
}

status=0
while IFS=: read -r file line ref; do
  if [[ $ref != "$flake" ]]; then
    echo "::error file=$file,line=$line::infrastructure-reusables $ref here, $flake in nixos/flake.lock"
    status=1
  fi
done < <(
  printf '%s\n' "$input"
  grep -rnoP --include='*.tf' 'infrastructure-reusables//[^"?]*\?ref=\K[^"]+' tofu
  grep -rnoP 'uses: *angel-penchev/infrastructure-reusables/[^@ ]*@\K[^ #]+' .github/workflows
)

if [[ $status == 0 ]]; then
  echo "infrastructure-reusables: $flake everywhere"
fi
exit $status
