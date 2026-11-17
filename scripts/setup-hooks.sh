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

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

# A clone that used the old qoax-githooks submodule keeps its checkout after
# the pull that removes the submodule. Nothing runs it, and .githooks/.gitignore
# hides it. Its removal is optional, so the script only says how.
top=$(git rev-parse --show-toplevel 2>/dev/null) || top=.
if [ -e "$top/.githooks/shared/.git" ] &&
  [ -z "$(git -C "$top" ls-files -s -- .githooks/shared 2>/dev/null)" ]; then
  printf 'note: .githooks/shared is a leftover checkout of the old qoax-githooks submodule.\n' >&2
  printf '  Nothing uses it now. To delete it, run these lines in %s:\n' "$top" >&2
  # shellcheck disable=SC2016
  printf '    %s\n' \
    'rm -rf .githooks/shared "$(git rev-parse --git-dir)/modules/.githooks"' \
    'rmdir "$(git rev-parse --git-dir)/modules" 2>/dev/null || true' \
    'git config --remove-section submodule..githooks/shared 2>/dev/null || true' >&2
fi

# Someone with their own hooks directory made a deliberate choice. Say what
# that costs them, and do not overwrite it. Only an unset value means "not
# set". An empty value is a value somebody wrote, and it turns hooks off.
configured=$(git config --get core.hooksPath) && set_already=1 || set_already=0

if [ "$set_already" = 1 ] && [ "$configured" != "$HOOKS_PATH" ]; then
  [ -z "$configured" ] && configured='an empty value' || configured="\"$configured\""
  printf '! core.hooksPath is set to %s, leaving it alone.\n' "$configured" >&2
  printf '  commit message validation is off. Run `git config core.hooksPath %s` to turn it on.\n' \
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
