#!/usr/bin/env bash
# dotfiles-version: 1.0.0
# sync-from-omnistation.sh — RUN THIS ON YOUR MAC.
#
# Pulls the dotfiles changes you made on the Omnistation sandbox (which can't
# push to personal GitHub), verifies the transfer is complete + intact, fast-
# forwards your Mac repo with the Omnistation commits, pushes to GitHub, and
# syncs the Claude memory files locally.
#
# Usage:
#   ./sync-from-omnistation.sh
#
# Overridable via env vars (defaults shown):
#   REMOTE=subansal@omni-lsn-talxl         # tsh target
#   REMOTE_PATH=~/dotfiles                  # path on the sandbox
#   REPO=~/dotfiles                         # your Mac canonical dotfiles repo
#   MAC_MEMORY_DIR=~/.claude/memory         # where to drop claude-memory locally
#
# Requires: tsh (logged in: `tsh login`), git with push access to origin.

set -euo pipefail

REMOTE="${REMOTE:-subansal@omni-lsn-talxl}"
REMOTE_PATH="${REMOTE_PATH:-~/dotfiles}"
REPO="${REPO:-$HOME/dotfiles}"
MAC_MEMORY_DIR="${MAC_MEMORY_DIR:-$HOME/.claude/memory}"

# Expand ~ in REPO/MAC_MEMORY_DIR if passed literally.
REPO="${REPO/#\~/$HOME}"
MAC_MEMORY_DIR="${MAC_MEMORY_DIR/#\~/$HOME}"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
SRC="$WORK/dotfiles"

say() { printf '\033[36m==>\033[0m %s\n' "$*"; }
die() { printf '\033[31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

# -- 0. sanity ---------------------------------------------------------------
command -v tsh >/dev/null || die "tsh not found. Install Teleport / run 'tsh login' first."
command -v git >/dev/null || die "git not found."

# -- 1. pull via tsh scp -----------------------------------------------------
say "Pulling $REMOTE:$REMOTE_PATH via tsh scp ..."
tsh scp -r "$REMOTE:$REMOTE_PATH" "$WORK/" \
  || die "tsh scp failed. Are you logged in? Try: tsh login"
[[ -d "$SRC" ]] || die "scp did not produce '$SRC' (expected a 'dotfiles' dir)."

# -- 2. verify the transfer is complete + intact -----------------------------
say "Verifying transfer ..."

# 2a. git integrity: the copy is a repo, fsck-clean, working tree matches HEAD.
if [[ -d "$SRC/.git" ]]; then
  git -C "$SRC" fsck --no-progress >/dev/null 2>&1 \
    || die "git fsck failed on the copy — transfer is corrupt. Re-run."
  if [[ -n "$(git -C "$SRC" status --porcelain)" ]]; then
    printf '\033[33mWARNING:\033[0m the copied repo has uncommitted changes:\n'
    git -C "$SRC" status --short
    printf 'Commit them on the sandbox first, or continue to ignore them.\n'
  fi
  INCOMING_HEAD="$(git -C "$SRC" rev-parse HEAD)"
  say "Incoming HEAD: $(git -C "$SRC" log --oneline -1)"
else
  die "the copy has no .git — can't verify or push. Re-run the scp."
fi

# 2b. required files present and non-empty.
REQUIRED=(
  install.sh install-linux.sh install-macos.sh nvidia-artifactory.sh
  .zshrc .gitconfig .vimrc .p10k.zsh ssh/config CLAUDE.md README.md
  .claude/settings.macos.json .claude/settings.linux.json
)
missing=0
for f in "${REQUIRED[@]}"; do
  [[ -s "$SRC/$f" ]] || { printf '  \033[31mMISSING/empty:\033[0m %s\n' "$f"; missing=1; }
done
[[ $missing -eq 0 ]] && say "All ${#REQUIRED[@]} required files present and non-empty."
[[ $missing -eq 1 ]] && die "Required files missing — incomplete transfer. Re-run."

# 2c. version markers consistent across all versioned files.
# NOTE: `|| true` is required — grep finds no match in files that mention
# "dotfiles-version:" only in prose (CLAUDE.md, README.md, claude-memory/*),
# and under `set -o pipefail` a failed pipeline in $(...) would abort the script.
VER="$(grep -m1 -oE 'dotfiles-version: [0-9]+\.[0-9]+\.[0-9]+' "$SRC/install.sh" | awk '{print $2}' || true)"
[[ -n "$VER" ]] || die "could not read dotfiles-version from install.sh"
say "Repo version: $VER"
badver=0
while IFS= read -r f; do
  fv="$(grep -m1 -oE 'dotfiles-version: [0-9]+\.[0-9]+\.[0-9]+' "$f" | awk '{print $2}' || true)"
  if [[ -n "$fv" && "$fv" != "$VER" ]]; then
    printf '  \033[31mversion mismatch:\033[0m %s -> %s\n' "${f#$SRC/}" "$fv"; badver=1
  fi
done < <(grep -rlE 'dotfiles-version:' "$SRC" --exclude-dir=.git 2>/dev/null || true)
[[ $badver -eq 1 ]] && die "inconsistent versions — transfer looks partial. Re-run."
say "All version markers agree on $VER."

# -- 3. integrate the Omnistation commits into the Mac repo + push -----------
if [[ -d "$REPO/.git" ]]; then
  say "Integrating into Mac repo: $REPO"
  git -C "$REPO" fetch "$SRC" HEAD 2>/dev/null || die "could not fetch from the copy."
  CUR_BRANCH="$(git -C "$REPO" rev-parse --abbrev-ref HEAD)"
  if git -C "$REPO" merge-base --is-ancestor "$(git -C "$REPO" rev-parse HEAD)" "$INCOMING_HEAD" 2>/dev/null; then
    git -C "$REPO" merge --ff-only "$INCOMING_HEAD" \
      || die "fast-forward failed unexpectedly."
    say "Fast-forwarded $CUR_BRANCH to the Omnistation commits."
  elif [[ "$(git -C "$REPO" rev-parse HEAD)" == "$INCOMING_HEAD" ]]; then
    say "Mac repo already at the incoming commit — nothing to integrate."
  else
    die "Mac repo ($CUR_BRANCH) has diverged from the Omnistation copy.
       Resolve manually:  git -C '$REPO' log --oneline --graph --all
       (the copy is preserved at: $SRC )"
  fi
  say "Commits to push:"
  git -C "$REPO" log --oneline origin/"$CUR_BRANCH"..HEAD || true
  say "Pushing to origin/$CUR_BRANCH ..."
  git -C "$REPO" push origin "$CUR_BRANCH"
  PUSHED_REPO="$REPO"
else
  printf '\033[33mNote:\033[0m no Mac repo at %s — pushing directly from the copy.\n' "$REPO"
  printf '      (set REPO=... to keep your Mac clone in sync next time)\n'
  say "Pushing to origin from the copy ..."
  git -C "$SRC" push origin HEAD
  PUSHED_REPO="$SRC"
fi

# -- 4. sync Claude memory locally -------------------------------------------
# The memory/learnings travel in the repo under claude-memory/ (now synced via
# git). Drop a local copy where your Mac Claude can read it too. CLAUDE.md in
# the repo is auto-read by Claude when working in the repo regardless.
if [[ -d "$PUSHED_REPO/claude-memory" ]]; then
  say "Syncing Claude memory -> $MAC_MEMORY_DIR"
  mkdir -p "$MAC_MEMORY_DIR"
  cp -f "$PUSHED_REPO"/claude-memory/*.md "$MAC_MEMORY_DIR"/ 2>/dev/null || true
  ls -1 "$MAC_MEMORY_DIR"/*.md 2>/dev/null | sed 's/^/  /'
fi

echo ""
say "Done. Pushed version $VER. Open a new terminal to pick up shell changes."
