#!/usr/bin/env bash
# dotfiles-version: 1.0.3
# install.sh — the ONE command to run on any machine.
#
# You never have to remember which installer to use: this detects the OS and
# hands off to the right one, after a preflight that verifies the scripts it
# depends on are present and at the SAME version (so a half-synced copy fails
# loudly instead of doing something weird).
#
#   ./install.sh
#
# Everything is idempotent and safe to re-run.

set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Single source of truth for the repo version. Bump this when you change the
# scripts; every versioned file must carry a matching "# dotfiles-version:".
DOTFILES_VERSION="1.0.3"

# require_version <file> — file must exist and declare our exact version.
require_version() {
  local f="$1" v
  if [[ ! -f "$f" ]]; then
    echo "ERROR: required file missing: $f" >&2
    echo "       Your dotfiles copy looks incomplete — re-sync the whole repo." >&2
    exit 1
  fi
  v="$(grep -m1 -oE '# dotfiles-version: [0-9]+\.[0-9]+\.[0-9]+' "$f" | awk '{print $3}')"
  if [[ -z "$v" ]]; then
    echo "ERROR: $(basename "$f") has no '# dotfiles-version:' marker." >&2
    exit 1
  fi
  if [[ "$v" != "$DOTFILES_VERSION" ]]; then
    echo "ERROR: version mismatch for $(basename "$f"): found $v, expected $DOTFILES_VERSION." >&2
    echo "       The scripts are out of sync. Re-sync the whole repo, then re-run." >&2
    exit 1
  fi
  echo "  ok: $(basename "$f") @ $v"
}

case "$(uname -s)" in
  Darwin) OS_INSTALLER="install-macos.sh" ;;
  Linux)  OS_INSTALLER="install-linux.sh" ;;
  *) echo "ERROR: unsupported OS '$(uname -s)'. Supported: macOS, Linux." >&2; exit 1 ;;
esac

echo "==> dotfiles v$DOTFILES_VERSION — preflight (verifying scripts present + version-matched)"
require_version "$DIR/$OS_INSTALLER"
require_version "$DIR/.zshrc"
# Linux may also use the NVIDIA Artifactory bootstrap; verify it if present.
if [[ "$(uname -s)" == "Linux" && -f "$DIR/nvidia-artifactory.sh" ]]; then
  require_version "$DIR/nvidia-artifactory.sh"
fi
echo "==> preflight passed; running $OS_INSTALLER"
echo ""

exec bash "$DIR/$OS_INSTALLER" "$@"
