#!/bin/sh
#
# Enables commit message validation in this repository. Safe to run again.
#
# For repositories with no package manager to hang an install step on: call it
# from a Makefile target, a bootstrap script, or by hand after cloning.
#
#   sh scripts/setup-hooks.sh
#
# It never fails the caller: no git, or a checkout that is not a work tree, is
# a reason to skip rather than an error.

set -u

HOOKS_PATH=.githooks
SUBMODULE=.githooks/shared

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

# The shared hook lives in a submodule, and a fresh clone leaves it empty.
if [ ! -e "$SUBMODULE/commit-msg" ]; then
  if ! git submodule update --init "$SUBMODULE" >/dev/null 2>&1; then
    printf '! could not check out %s, commit message validation is off\n' "$SUBMODULE" >&2
    exit 0
  fi
fi

# Someone with their own hooks directory made a deliberate choice; say what
# that costs them rather than overwriting it. An unset value is the only "not
# set" answer — an empty one is a value somebody wrote, and it disables hooks.
configured=$(git config --get core.hooksPath) && set_already=1 || set_already=0

if [ "$set_already" = 1 ] && [ "$configured" != "$HOOKS_PATH" ]; then
  [ -z "$configured" ] && configured='an empty value' || configured="\"$configured\""
  printf '! core.hooksPath is set to %s, leaving it alone.\n' "$configured" >&2
  printf '  commit message validation is off — run `git config core.hooksPath %s` to enable it.\n' \
    "$HOOKS_PATH" >&2
  exit 0
fi

if [ "$configured" = "$HOOKS_PATH" ]; then
  exit 0
fi

if ! git config core.hooksPath "$HOOKS_PATH"; then
  printf '! could not set core.hooksPath, commit message validation is off\n' >&2
  exit 0
fi

printf '✓ commit message validation enabled (core.hooksPath = %s)\n' "$HOOKS_PATH"
