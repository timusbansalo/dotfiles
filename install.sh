#!/usr/bin/env bash
# install.sh — the ONE command to run on any machine.
#
# You never have to remember which installer to use: this detects the OS and
# hands off to the right one. On Linux, install-linux.sh further detects the
# distro, package manager, sudo capability, and NVIDIA environment
# (standard / NVIDIA VM / Omnistation sandbox) and adapts accordingly.
#
#   curl/clone the repo, then:   ./install.sh
#
# Everything is idempotent and safe to re-run.

set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

case "$(uname -s)" in
  Darwin)
    echo "==> macOS detected — running install-macos.sh"
    exec bash "$DIR/install-macos.sh" "$@"
    ;;
  Linux)
    echo "==> Linux detected — running install-linux.sh"
    exec bash "$DIR/install-linux.sh" "$@"
    ;;
  *)
    echo "ERROR: unsupported OS '$(uname -s)'. Supported: macOS (Darwin), Linux." >&2
    exit 1
    ;;
esac
