#!/usr/bin/env bash
#
# install-hooks.sh — install the splsleep pre-commit hook.
#
# Copies inst/hooks/pre-commit into .git/hooks/ so the local repository
# refuses commits whose root copy of a pipeline script has drifted from its
# inst/scripts/ twin. CI (test-script-copies-in-sync.R) enforces the same
# invariant on push; this catches it before the commit exists.
#
# The hook is versioned under inst/hooks/ (ships with the package) but git
# only reads hooks from .git/hooks/ -- hence this one-time installer.
# Re-run after cloning or after .git/hooks/ is wiped.
#
# Uninstall:  rm .git/hooks/pre-commit

set -euo pipefail

HOOK_SRC="$(
  cd "$(dirname "$0")" && pwd
)/pre-commit"
GIT_DIR="$(git rev-parse --git-dir 2>/dev/null || true)"
if [ -z "$GIT_DIR" ] || [ ! -d "$GIT_DIR" ]; then
  echo "error: not inside a git work tree; nothing to install into." >&2
  exit 1
fi

# Prefer the common layout (.git/hooks) but honour unusual git-dir locations.
HOOK_DST="$GIT_DIR/hooks/pre-commit"
if [ ! -d "$(dirname "$HOOK_DST")" ]; then
  HOOK_DST="$(dirname "$HOOK_DST")/pre-commit"
fi

cp "$HOOK_SRC" "$HOOK_DST" && chmod +x "$HOOK_DST"
echo "installed: $HOOK_DST"

# Smoke test: the hook must pass on an unchanged tree.
cd "$(git rev-parse --show-toplevel)"
if bash "$HOOK_DST"; then
  echo "smoke test: hook runs and passes (copies identical)."
else
  echo "warning: smoke test failed; current tree may already be divergent." >&2
  exit 1
fi