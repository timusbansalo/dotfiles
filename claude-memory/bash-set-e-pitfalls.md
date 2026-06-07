---
name: bash-set-e-pitfalls
description: set -euo pipefail traps found while testing the dotfiles installer
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 16fc523d-f1cf-4090-81b7-80b261e20d7f
---

While testing `install-linux.sh` (see [[dotfiles-repo]]), three `set -euo pipefail` traps each aborted the script mid-run. Watch for these when writing/reviewing bash:

**Why:** under `set -e`, a non-zero status from a *bare* command (including a function call and assignments) kills the script; `pipefail` makes a pipeline fail if any stage fails; `chsh` reads its password from `/dev/tty` so stdin redirection can't stop it blocking.

**How to apply:**
- A "best-effort/optional" helper called as a bare statement must `return 0` on the not-found path, not `return 1` (or call it with `|| true`). A `return 1` there aborts everything.
- `var="$(cmd | pipeline)"` aborts if any stage fails under pipefail (e.g. `curl -f` hitting 403). Wrap: `var="$(... || true)"`.
- A `for` loop whose last executed command is `[[ test ]] && action` returns the failing test's status → can trip `set -e`. Use `if [[ test ]]; then action; fi` instead (a false `if` with no else returns 0).
- `chsh -s` blocks forever waiting on `/dev/tty` in a non-interactive run. Gate on `[[ -t 0 ]]`; when not a TTY run it under `setsid timeout -k 2 8 chsh ...` so it fails fast to a fallback.
- Use `DEBIAN_FRONTEND=noninteractive` (and `NEEDRESTART_MODE=a`) for apt in scripts, or a pending-kernel debconf/whiptail dialog hangs the run.
