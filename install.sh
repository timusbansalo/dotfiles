#!/usr/bin/env bash
# install.sh — sets up Oh My Zsh + Powerlevel10k + plugins + font,
# then symlinks the dotfiles from this repo into $HOME.
#
# Safe to re-run: backs up any existing files it would replace,
# skips installs that are already in place.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$HOME/.dotfiles-backup-$(date +%Y%m%d-%H%M%S)"

echo "=========================================="
echo " dotfiles install"
echo "=========================================="
echo "  repo:    $REPO_DIR"
echo "  backups: $BACKUP_DIR  (created only if needed)"
echo ""

# -- OS check ----------------------------------------------------------------
if [[ "$(uname)" != "Darwin" ]]; then
  echo "ERROR: this installer assumes macOS. You're on $(uname)." >&2
  exit 1
fi

# -- Homebrew ----------------------------------------------------------------
if ! command -v brew >/dev/null 2>&1; then
  echo "--- Installing Homebrew (you'll be prompted for password) ---"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  # shellcheck disable=SC2016
  echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
  eval "$(/opt/homebrew/bin/brew shellenv)"
else
  echo "  brew already installed: $(brew --version | head -1)"
fi

# -- Brew packages -----------------------------------------------------------
echo ""
echo "--- Installing brew formulae / casks ---"
brew_install() {
  if brew list "$1" >/dev/null 2>&1; then
    echo "  $1: already installed"
  else
    echo "  installing $1..."
    brew install "$1"
  fi
}
brew_install zsh-autosuggestions
brew_install zsh-syntax-highlighting
brew_install fzf
# Nerd Font for Powerlevel10k icons
if brew list --cask font-meslo-lg-nerd-font >/dev/null 2>&1; then
  echo "  font-meslo-lg-nerd-font: already installed"
else
  echo "  installing MesloLGS Nerd Font (cask)..."
  brew install --cask font-meslo-lg-nerd-font
fi

# fzf key bindings + completion
if [[ ! -f "$HOME/.fzf.zsh" ]]; then
  echo "  setting up fzf key bindings..."
  yes | "$(brew --prefix)/opt/fzf/install" --key-bindings --completion --no-update-rc >/dev/null
fi

# -- Oh My Zsh ---------------------------------------------------------------
echo ""
echo "--- Oh My Zsh ---"
if [[ -d "$HOME/.oh-my-zsh" ]]; then
  echo "  already installed at ~/.oh-my-zsh"
else
  echo "  installing..."
  RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi

# -- Powerlevel10k -----------------------------------------------------------
echo ""
echo "--- Powerlevel10k theme ---"
P10K_DIR="$HOME/.oh-my-zsh/custom/themes/powerlevel10k"
if [[ -d "$P10K_DIR" ]]; then
  echo "  already cloned at $P10K_DIR (running git pull)"
  git -C "$P10K_DIR" pull --quiet || true
else
  git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$P10K_DIR"
fi

# -- OMZ-managed plugin clones (so plugin=() entries find them) --------------
echo ""
echo "--- OMZ plugins ---"
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
for p in zsh-autosuggestions zsh-syntax-highlighting; do
  if [[ -d "$ZSH_CUSTOM/plugins/$p" ]]; then
    echo "  $p: already cloned"
  else
    echo "  cloning $p..."
    git clone --depth=1 "https://github.com/zsh-users/$p.git" "$ZSH_CUSTOM/plugins/$p"
  fi
done

# -- Symlinks ----------------------------------------------------------------
echo ""
echo "--- Symlinks ---"
link() {
  local src="$REPO_DIR/$1"
  local dst="$HOME/$1"
  if [[ ! -f "$src" ]]; then
    echo "  $1: source missing in repo, skipping"
    return
  fi
  if [[ -L "$dst" && "$(readlink "$dst")" == "$src" ]]; then
    echo "  $1: already linked correctly"
    return
  fi
  if [[ -e "$dst" || -L "$dst" ]]; then
    mkdir -p "$BACKUP_DIR"
    mv "$dst" "$BACKUP_DIR/$1"
    echo "  $1: backed up existing -> $BACKUP_DIR/$1"
  fi
  ln -s "$src" "$dst"
  echo "  $1 -> $src"
}
link .zshrc
link .gitconfig
link .gitignore_global

# Optional: link .p10k.zsh only if you've already run `p10k configure` and
# checked it into the repo.
if [[ -f "$REPO_DIR/.p10k.zsh" ]]; then
  link .p10k.zsh
fi

# -- Final notes -------------------------------------------------------------
echo ""
echo "=========================================="
echo " install complete"
echo "=========================================="
cat <<'EOF'

Next steps:

1. SET YOUR TERMINAL FONT to "MesloLGS NF Regular".
   - Terminal.app: Settings -> Profiles -> Font -> Change... -> pick "MesloLGS NF"
   - iTerm2:       Settings -> Profiles -> Text -> Font -> "MesloLGS NF"
   - VS Code:      add `"terminal.integrated.fontFamily": "MesloLGS NF"` to settings.json
   Without this you'll see boxes/question marks where icons should be.

2. OPEN A NEW TERMINAL WINDOW. Don't `source ~/.zshrc` in the current one —
   start fresh so OMZ + p10k initialize cleanly.

3. The Powerlevel10k CONFIGURATION WIZARD will run automatically the first time.
   It asks ~15 questions about how you want your prompt to look. Defaults are
   sensible; pick whatever you like. To re-run later: `p10k configure`.

4. Once you like your prompt, save it to the repo:
   cp ~/.p10k.zsh ~/Downloads/Claude/dotfiles/.p10k.zsh
   The next sync will push it.

5. Optional: run macos-defaults.sh to apply Finder/Dock/keyboard tweaks.
   ~/Downloads/Claude/dotfiles/macos-defaults.sh
EOF
