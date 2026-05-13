#!/usr/bin/env bash
# uninstall.sh — removes the symlinks created by install.sh.
# Does NOT uninstall Oh My Zsh, Powerlevel10k, plugins, or the font.
# That cleanup is left to you (OMZ has its own `uninstall_oh_my_zsh`).

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

unlink_if_ours() {
  local dst="$HOME/$1"
  local src="$REPO_DIR/$1"
  if [[ -L "$dst" && "$(readlink "$dst")" == "$src" ]]; then
    rm "$dst"
    echo "  removed $dst"
  elif [[ -e "$dst" ]]; then
    echo "  skipped $dst (not a symlink to this repo)"
  else
    echo "  $dst not present"
  fi
}

echo "Removing symlinks pointing to $REPO_DIR..."
unlink_if_ours .zshrc
unlink_if_ours .gitconfig
unlink_if_ours .gitignore_global
unlink_if_ours .p10k.zsh

echo ""
echo "Done. Your most recent backup directory is:"
ls -1dt "$HOME"/.dotfiles-backup-* 2>/dev/null | head -1 || echo "  (none found)"
echo ""
echo "To also remove Oh My Zsh: run \`uninstall_oh_my_zsh\` in a new shell."
