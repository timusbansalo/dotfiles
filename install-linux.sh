#!/usr/bin/env bash
# dotfiles-version: 1.0.0
# install-linux.sh — portable Linux dotfiles installer.
#
# Normally invoked via ./install.sh (the single entry point), but safe to run
# directly. Designed to run UNCHANGED on any Linux host. It probes the
# environment and adapts instead of assuming one setup:
#
#   - Distro + package manager: apt/dnf/yum/zypper/pacman/apk/brew (or none)
#   - Privilege model: root | passwordless-sudo | sudo-with-password |
#     no-sudo/non-interactive  -> installs, prompts, or degrades accordingly
#   - NVIDIA environment: standard | nvidia-vm | omnistation. Omnistation has
#     no open internet (github.com blocked by an egress ACL), so we NEVER try
#     to clone/download from github there — we use apt + NVIDIA Artifactory
#     (pip/cargo/npm) per NVIDIA policy, and never proxy around the ACL.
#   - Prompt: Linux uses the simple native zsh prompt in .zshrc (no p10k),
#     which works even on Omnistation. p10k stays macOS-only.
#   - Installs prerequisites (git, curl required; zsh best-effort), zsh plugins
#     (OMZ clone when github is reachable, else apt packages), fzf, eza/ripgrep,
#     a Nerd Font (from raw.githubusercontent, which Omnistation allows), Vim +
#     vim-plug, and renders the per-OS Claude settings.
#   - Symlinks dotfiles (and an SSH config if the repo has one — never keys).
#   - Switches the login shell to zsh, adapting the fallback to the real shell.
#   - Prints a summary of what was done / skipped / needs attention.
#
# Env overrides: NV_ENV=standard|nvidia-vm|omnistation, GH_OK=0|1 (force the
# github-reachability decision). Safe to re-run.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$HOME/.dotfiles-backup-$(date +%Y%m%d-%H%M%S)"
NOTES=()   # collected and printed in the final summary

note() { NOTES+=("$1"); }

# -- OS guard ----------------------------------------------------------------
OS="$(uname -s)"
if [[ "$OS" == "Darwin" ]]; then
  echo "ERROR: this is the Linux installer. Use ./install.sh (it picks macOS)." >&2
  exit 1
fi

# -- Distro detection --------------------------------------------------------
DISTRO_NAME="unknown"; DISTRO_ID="unknown"
if [[ -r /etc/os-release ]]; then
  # shellcheck disable=SC1091
  . /etc/os-release
  DISTRO_NAME="${PRETTY_NAME:-${NAME:-unknown}}"
  DISTRO_ID="${ID:-unknown}"
fi

# -- Package manager detection -----------------------------------------------
PM="none"
for c in apt-get dnf yum zypper pacman apk brew; do
  if command -v "$c" >/dev/null 2>&1; then PM="$c"; break; fi
done

# -- Privilege detection -----------------------------------------------------
# SUDO_MODE: root | nopasswd | password | noprompt | none
detect_sudo() {
  if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then echo "root"; return; fi
  if ! command -v sudo >/dev/null 2>&1; then echo "none"; return; fi
  if sudo -n true 2>/dev/null; then echo "nopasswd"; return; fi
  if [[ -t 0 || -t 1 ]]; then echo "password"; else echo "noprompt"; fi
}
SUDO_MODE="$(detect_sudo)"

SUDO=""
CAN_INSTALL=0
if [[ "$PM" == "brew" ]]; then
  CAN_INSTALL=1; SUDO=""
elif [[ "$PM" != "none" ]]; then
  case "$SUDO_MODE" in
    root)               CAN_INSTALL=1; SUDO="" ;;
    nopasswd|password)  CAN_INSTALL=1; SUDO="sudo" ;;
    *)                  CAN_INSTALL=0; SUDO="" ;;
  esac
fi
CAN_INSTALL_NI=0
if [[ "$PM" != "none" ]] && { [[ "$PM" == "brew" || "$SUDO_MODE" == "root" || "$SUDO_MODE" == "nopasswd" ]]; }; then
  CAN_INSTALL_NI=1
fi
ARCH="$(uname -m)"

# -- NVIDIA environment detection --------------------------------------------
# NV_ENV: standard | nvidia-vm | omnistation  (override via env NV_ENV=...)
if [[ -z "${NV_ENV:-}" ]]; then
  if [[ "$(hostname)" == omni-* ]] || [[ -n "${SSH_SESSION_WEBPROXY_ADDR:-}" ]]; then
    NV_ENV="omnistation"
  elif [[ "$(hostname -f 2>/dev/null)" == *.nvidia.com ]] || command -v artifactory-download >/dev/null 2>&1; then
    NV_ENV="nvidia-vm"
  else
    NV_ENV="standard"
  fi
fi
# Can we reach github.com apex (needed for any git clone / release download)?
# Omnistation blocks it (503). Probe once; allow override via GH_OK=0|1.
if [[ -n "${GH_OK:-}" ]]; then
  NV_GITHUB_OK="$GH_OK"
elif curl -fsS -m 6 -o /dev/null https://github.com 2>/dev/null; then
  NV_GITHUB_OK=1
else
  NV_GITHUB_OK=0
fi

echo "=========================================="
echo " dotfiles install (Linux)"
echo "=========================================="
echo "  host:     $(hostname)"
echo "  os:       $OS $(uname -r)"
echo "  distro:   $DISTRO_NAME ($DISTRO_ID)"
echo "  pkgmgr:   $PM"
echo "  sudo:     $SUDO_MODE"
echo "  nvidia:   $NV_ENV"
echo "  github:   $([[ $NV_GITHUB_OK -eq 1 ]] && echo 'reachable (clones OK)' || echo 'BLOCKED (apt/Artifactory only)')"
echo "  install:  $([[ $CAN_INSTALL -eq 1 ]] && echo 'yes' || echo 'no (user-level only)')"
echo "  repo:     $REPO_DIR"
echo "  shell:    $SHELL"
echo ""
if [[ "$SUDO_MODE" == "password" ]]; then
  echo "  NOTE: sudo will prompt for your password when installing packages."; echo ""
elif [[ "$SUDO_MODE" == "noprompt" || "$SUDO_MODE" == "none" ]]; then
  echo "  NOTE: no usable sudo — missing system packages will be skipped."; echo ""
fi
if [[ "$NV_ENV" == "omnistation" ]]; then
  echo "  NOTE: Omnistation sandbox — github.com is blocked by the egress ACL."
  echo "        Using apt + NVIDIA Artifactory only; never proxying around it."
  echo "        See ~/dotfiles/CLAUDE.md for the package policy."; echo ""
fi

# -- Package manager install helper ------------------------------------------
APT_UPDATED=""
pm_install() {
  local pkg="$1"
  case "$PM" in
    apt-get)
      if [[ -z "$APT_UPDATED" ]]; then
        $SUDO env DEBIAN_FRONTEND=noninteractive apt-get update -y; APT_UPDATED=1
      fi
      $SUDO env DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a apt-get install -y "$pkg" ;;
    dnf)    $SUDO dnf install -y "$pkg" ;;
    yum)    $SUDO yum install -y "$pkg" ;;
    zypper) $SUDO zypper --non-interactive install "$pkg" ;;
    pacman) $SUDO pacman -S --noconfirm --needed "$pkg" ;;
    apk)    $SUDO apk add "$pkg" ;;
    brew)   brew install "$pkg" ;;
    *)      return 1 ;;
  esac
}

# ensure_cmd <command> <package> <required:yes|no>
ensure_cmd() {
  local cmd="$1" pkg="${2:-$1}" required="${3:-yes}"
  if command -v "$cmd" >/dev/null 2>&1; then
    echo "  $cmd: present ($(command -v "$cmd"))"; return 0
  fi
  if [[ "$CAN_INSTALL" -ne 1 ]]; then
    if [[ "$required" == "yes" ]]; then
      echo "ERROR: '$cmd' is required but missing, and packages can't be installed" >&2
      echo "       here (pkgmgr=$PM, sudo=$SUDO_MODE). Install '$pkg' then re-run." >&2
      exit 1
    fi
    echo "  $cmd: missing; can't install (sudo=$SUDO_MODE) — skipping"
    note "$cmd not installed (no install rights). Install '$pkg' later and re-run."
    return 1
  fi
  echo "  $cmd: missing -> installing '$pkg' via $PM"
  if pm_install "$pkg" && command -v "$cmd" >/dev/null 2>&1; then return 0; fi
  if [[ "$required" == "yes" ]]; then
    echo "ERROR: failed to install required package '$pkg' via $PM." >&2; exit 1
  fi
  echo "  $cmd: install failed — skipping"
  note "$cmd install via $PM failed; install '$pkg' manually and re-run."
  return 1
}

# -- Optional-tool helpers ---------------------------------------------------
gh_latest_dl() {  # <owner/repo> <regex over asset url> -> first matching url
  curl -fsSL "https://api.github.com/repos/$1/releases/latest" 2>/dev/null \
    | grep -oE '"browser_download_url": *"[^"]+"' \
    | sed -E 's/.*"(https[^"]+)".*/\1/' \
    | grep -E "$2" | head -1
}
fetch_bin_from_tarball() {  # <url> <bin-name-in-archive> <install-as>
  local url="$1" bin="$2" as="$3" tmp found
  tmp="$(mktemp -d)"
  if curl -fsSL "$url" -o "$tmp/pkg" && tar -xf "$tmp/pkg" -C "$tmp" 2>/dev/null; then
    found="$(find "$tmp" -type f -name "$bin" 2>/dev/null | head -1)"
    if [[ -n "$found" ]]; then
      mkdir -p "$HOME/.local/bin"
      if install -m 0755 "$found" "$HOME/.local/bin/$as"; then rm -rf "$tmp"; return 0; fi
    fi
  fi
  rm -rf "$tmp"; return 1
}
# install_optional <cmd> <pm_pkg> <gh_repo> <asset_regex> <bin_in_archive> [direct_url] [crate]
# Order: (1) apt/pkgmgr if non-interactive, (2) github release IF github
# reachable, (3) cargo (Artifactory-backed on NVIDIA) if a crate is given,
# (4) a clear note. Never proxies around a blocked ACL.
install_optional() {
  local cmd="$1" pkg="$2" repo="$3" pat="$4" bin="$5" direct="${6:-}" crate="${7:-}" url
  if command -v "$cmd" >/dev/null 2>&1; then
    echo "  $cmd: present ($(command -v "$cmd"))"; return 0
  fi
  if [[ "$CAN_INSTALL_NI" -eq 1 ]] && pm_install "$pkg" >/dev/null 2>&1 \
       && command -v "$cmd" >/dev/null 2>&1; then
    echo "  $cmd: installed via $PM ($pkg)"; return 0
  fi
  if [[ "$NV_GITHUB_OK" == "1" ]]; then
    if [[ -n "$direct" ]] && fetch_bin_from_tarball "$direct" "$bin" "$cmd"; then
      echo "  $cmd: installed user-local -> ~/.local/bin/$cmd"; return 0
    fi
    if [[ -n "$repo" ]]; then
      url="$(gh_latest_dl "$repo" "$pat" || true)"
      if [[ -n "$url" ]] && fetch_bin_from_tarball "$url" "$bin" "$cmd"; then
        echo "  $cmd: installed user-local -> ~/.local/bin/$cmd"; return 0
      fi
    fi
  fi
  if [[ -n "$crate" ]] && command -v cargo >/dev/null 2>&1; then
    echo "  $cmd: trying 'cargo install $crate' (Artifactory-backed on NVIDIA)..."
    if cargo install "$crate" >/dev/null 2>&1 && command -v "$cmd" >/dev/null 2>&1; then
      echo "  $cmd: installed via cargo"; return 0
    fi
  fi
  echo "  $cmd: not installed (skipped)"
  if [[ "$NV_ENV" == "omnistation" ]]; then
    note "$cmd not in apt — per NVIDIA policy install via pip/cargo/npm (Artifactory) or ask a human to mirror it. Do NOT proxy around the ACL. See ~/dotfiles/CLAUDE.md."
  elif [[ "$CAN_INSTALL_NI" -ne 1 && "$PM" != "none" ]]; then
    note "$cmd missing — run yourself: ${SUDO:+sudo }$PM install $pkg"
  else
    note "$cmd missing — install '$pkg' via $PM, or from github.com/$repo/releases"
  fi
  return 0   # optional: never fatal under set -e
}

# -- Prerequisites -----------------------------------------------------------
echo "--- prerequisites ---"
ensure_cmd git  git  yes
ensure_cmd curl curl yes
ZSH_OK=0
if ensure_cmd zsh zsh no; then ZSH_OK=1; fi
echo ""

# -- NVIDIA Artifactory (wire pip/npm so installs work without github) -------
# On NVIDIA environments, point pip/npm at the internal Artifactory mirror so
# package installs (and the cargo fallback below) work without open internet.
# Skip with NV_ARTIFACTORY=0.
if [[ "$NV_ENV" == "omnistation" || "$NV_ENV" == "nvidia-vm" ]] \
     && [[ "${NV_ARTIFACTORY:-1}" == "1" ]] && [[ -f "$REPO_DIR/nvidia-artifactory.sh" ]]; then
  echo "--- NVIDIA Artifactory (pip/npm registries) ---"
  bash "$REPO_DIR/nvidia-artifactory.sh" || note "Artifactory bootstrap had warnings."
  echo ""
fi

# -- Oh My Zsh (only when github is reachable) -------------------------------
# On Linux the prompt comes from .zshrc's native prompt (not p10k), so OMZ is
# optional. When github is blocked (Omnistation), we skip it and rely on the
# apt-installed plugins that .zshrc sources directly.
echo "--- Oh My Zsh ---"
if [[ -d "$HOME/.oh-my-zsh" ]]; then
  echo "  already at ~/.oh-my-zsh"
elif [[ "$NV_GITHUB_OK" == "1" ]]; then
  echo "  installing..."
  if RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
       sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"; then
    echo "  installed"
  else
    echo "  OMZ install failed — falling back to native prompt + apt plugins"
    note "Oh My Zsh install failed; .zshrc uses the native prompt + apt plugins."
  fi
else
  echo "  github blocked ($NV_ENV) — skipping OMZ; .zshrc uses native prompt + apt plugins"
fi

# -- Powerlevel10k (github-gated) --------------------------------------------
# When p10k is installed, .zshrc uses the committed ~/.p10k.zsh (same lean
# prompt as macOS). When it can't be installed (Omnistation: github blocked),
# .zshrc falls back to the simple native prompt automatically.
echo ""
echo "--- Powerlevel10k ---"
P10K_DIR="$HOME/.oh-my-zsh/custom/themes/powerlevel10k"
if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
  echo "  no Oh My Zsh — Linux will use the simple native prompt"
elif [[ -d "$P10K_DIR" ]]; then
  echo "  already cloned, pulling updates"
  git -C "$P10K_DIR" pull --quiet 2>/dev/null || true
elif [[ "$NV_GITHUB_OK" == "1" ]]; then
  echo "  cloning powerlevel10k..."
  if git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$P10K_DIR"; then
    echo "  installed (will use ~/.p10k.zsh)"
  else
    echo "  clone failed — native prompt will be used"
    note "Powerlevel10k clone failed; using the native prompt."
  fi
else
  echo "  github blocked — using the simple native prompt instead of p10k"
fi

# -- zsh plugins -------------------------------------------------------------
# With OMZ + github: clone into OMZ custom. Otherwise: apt packages, which
# .zshrc sources from /usr/share when OMZ is absent.
echo ""
echo "--- zsh plugins ---"
if [[ -d "$HOME/.oh-my-zsh" && "$NV_GITHUB_OK" == "1" ]]; then
  ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
  for p in zsh-autosuggestions zsh-syntax-highlighting; do
    if [[ -d "$ZSH_CUSTOM/plugins/$p" ]]; then
      echo "  $p: already cloned (OMZ)"
    else
      echo "  cloning $p (OMZ)..."
      git clone --depth=1 "https://github.com/zsh-users/$p.git" "$ZSH_CUSTOM/plugins/$p" || \
        note "$p clone failed."
    fi
  done
else
  for p in zsh-autosuggestions zsh-syntax-highlighting; do
    if [[ "$CAN_INSTALL_NI" == "1" ]]; then
      if pm_install "$p" >/dev/null 2>&1; then echo "  $p: installed via $PM"
      else echo "  $p: not installed"; note "$p missing — install via $PM (powers autosuggestions/highlighting)."; fi
    else
      echo "  $p: skipped (no install rights)"; note "$p not installed (no install rights)."
    fi
  done
fi

# -- CLI tools (eza, ripgrep, ripgrep-all) -----------------------------------
echo ""
echo "--- CLI tools (eza, ripgrep, ripgrep-all) ---"
install_optional eza eza         eza-community/eza  "${ARCH}-unknown-linux-gnu\\.tar\\.gz$"  eza \
  "https://github.com/eza-community/eza/releases/latest/download/eza_${ARCH}-unknown-linux-gnu.tar.gz" eza
install_optional rg  ripgrep     BurntSushi/ripgrep "${ARCH}-unknown-linux-musl\\.tar\\.gz$" rg "" ripgrep
install_optional rga ripgrep-all phiresky/ripgrep-all "${ARCH}-unknown-linux-musl\\.tar\\.gz$" rga "" ripgrep_all

# -- fzf + key bindings / completion -----------------------------------------
echo ""
echo "--- fzf ---"
if [[ -f "$HOME/.fzf.zsh" ]]; then
  echo "  ~/.fzf.zsh already present"
else
  # Prefer system fzf (apt works on Omnistation); clone only if github is open.
  if ! command -v fzf >/dev/null 2>&1 && [[ "$CAN_INSTALL_NI" == "1" ]]; then
    pm_install fzf >/dev/null 2>&1 || true
  fi
  if command -v fzf >/dev/null 2>&1; then
    {
      if fzf --zsh >/dev/null 2>&1; then
        echo 'source <(fzf --zsh)'                       # newer fzf
      else
        for kb in /usr/share/doc/fzf/examples/key-bindings.zsh /usr/share/fzf/key-bindings.zsh; do
          [[ -f "$kb" ]] && echo "source $kb"
        done
        for cp in /usr/share/doc/fzf/examples/completion.zsh /usr/share/fzf/completion.zsh; do
          [[ -f "$cp" ]] && echo "source $cp"
        done
      fi
    } > "$HOME/.fzf.zsh"
    echo "  wrote ~/.fzf.zsh (system fzf)"
  elif [[ "$NV_GITHUB_OK" == "1" ]]; then
    echo "  cloning fzf -> ~/.fzf"
    if git clone --depth=1 https://github.com/junegunn/fzf.git "$HOME/.fzf" >/dev/null 2>&1 \
       && "$HOME/.fzf/install" --key-bindings --completion --no-update-rc >/dev/null 2>&1; then
      echo "  configured ~/.fzf.zsh (cloned)"
    else
      echo "  fzf not set up"; note "fzf not configured."
    fi
  else
    echo "  fzf not set up (github blocked, not in apt)"
    note "fzf missing — install via $PM."
  fi
fi

# -- Nerd Font (best-effort; raw.githubusercontent works on Omnistation) -----
echo ""
echo "--- MesloLGS Nerd Font (best-effort) ---"
FONT_DIR="$HOME/.local/share/fonts"
if ls "$FONT_DIR"/MesloLGS*NF*.ttf >/dev/null 2>&1; then
  echo "  already present in $FONT_DIR"
else
  set +e
  mkdir -p "$FONT_DIR"
  base="https://raw.githubusercontent.com/romkatv/powerlevel10k-media/master"
  ok=1
  for f in "MesloLGS NF Regular.ttf" "MesloLGS NF Bold.ttf" \
           "MesloLGS NF Italic.ttf" "MesloLGS NF Bold Italic.ttf"; do
    curl -fsSL "$base/${f// /%20}" -o "$FONT_DIR/$f" || ok=0
  done
  if [[ "$ok" == "1" ]]; then
    command -v fc-cache >/dev/null 2>&1 && fc-cache -f "$FONT_DIR" >/dev/null 2>&1
    echo "  installed MesloLGS NF into $FONT_DIR"
  else
    echo "  font download failed — skipping"
    note "Nerd Font not installed; set your terminal font to MesloLGS NF manually."
  fi
  set -e
fi

# -- Linux-local extras (host-specific; ls/PATH now handled in .zshrc) -------
echo ""
echo "--- writing ~/.zshrc.linux-local ---"
cat > "$HOME/.zshrc.linux-local" <<'ZRC'
# .zshrc.linux-local — sourced from .zshrc on Linux only. Host-specific extras.
# (ls aliases, colors, and PATH are handled in .zshrc itself now.)
command -v python3 >/dev/null && alias py='python3'
alias scg='cd ~/scg-domain-supervisor 2>/dev/null || cd ~/'
ZRC
echo "  written."

# .zshrc already sources this file (no hook to append in the new layout).
if ! grep -q "zshrc.linux-local" "$REPO_DIR/.zshrc"; then
  cat >> "$REPO_DIR/.zshrc" <<'TAIL'

# -- Linux-local overrides (added by install-linux.sh) ----------------------
[[ -f "$HOME/.zshrc.linux-local" && "$(uname)" == "Linux" ]] && source "$HOME/.zshrc.linux-local"
TAIL
  note "Repo .zshrc was missing the linux-local hook — appended it; commit to persist."
fi

# -- Symlink helper (files AND directories) ----------------------------------
link() {
  local rel="$1" src="$REPO_DIR/$1" dst="$HOME/$1"
  if [[ ! -e "$src" ]]; then echo "  $rel: not in repo, skipping"; return 0; fi
  if [[ -L "$dst" && "$(readlink "$dst")" == "$src" ]]; then echo "  $rel: already linked correctly"; return 0; fi
  mkdir -p "$(dirname "$dst")"
  if [[ -e "$dst" || -L "$dst" ]]; then
    mkdir -p "$BACKUP_DIR/$(dirname "$rel")"; mv "$dst" "$BACKUP_DIR/$rel"
    echo "  $rel: backed up existing -> $BACKUP_DIR/$rel"
  fi
  ln -s "$src" "$dst"; echo "  $rel -> $src"; return 0
}

# -- Shell + git dotfiles ----------------------------------------------------
echo ""
echo "--- shell/git dotfiles ---"
link .zshrc
link .gitconfig
link .gitignore_global
[[ -f "$REPO_DIR/.p10k.zsh" ]] && link .p10k.zsh   # used when p10k is installed

# -- Vim config --------------------------------------------------------------
echo ""
echo "--- Vim ---"
vim_any=0
for rel in .vimrc .vim .ideavimrc .config/nvim; do
  if [[ -e "$REPO_DIR/$rel" ]]; then link "$rel" && vim_any=1; fi
done
if [[ $vim_any -eq 0 ]]; then
  echo "  no Vim configs in repo — nothing to link"
elif [[ -f "$REPO_DIR/.vimrc" ]] && grep -q "plug#begin" "$REPO_DIR/.vimrc"; then
  VIM_OK=0
  ensure_cmd vim vim no && VIM_OK=1
  PLUG="$HOME/.vim/autoload/plug.vim"
  # vim-plug self-hosts on raw.githubusercontent, which Omnistation allows.
  if [[ -f "$PLUG" ]]; then
    echo "  vim-plug already present"
  else
    echo "  installing vim-plug -> $PLUG"
    curl -fsSL https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim \
      --create-dirs -o "$PLUG" && echo "  vim-plug installed" \
      || { echo "  vim-plug download failed"; note "vim-plug install failed; run :PlugInstall later."; }
  fi
  # :PlugInstall fetches plugins from github.com — only attempt if reachable.
  if [[ "$VIM_OK" == "1" && -f "$PLUG" && "$NV_GITHUB_OK" == "1" ]]; then
    echo "  installing plugins (headless :PlugInstall)..."
    vim -u "$HOME/.vimrc" +PlugInstall +qall </dev/null >/dev/null 2>&1 || true
    echo "  done"
  elif [[ "$NV_GITHUB_OK" != "1" ]]; then
    echo "  github blocked — skipping :PlugInstall (.vimrc still works; plugins load if present)"
    note "Vim plugins not installed (github blocked). Mirror them via GitLab or run :PlugInstall where github is reachable."
  fi
fi

# -- Claude config (per-OS template rendered with this host's \$HOME) ---------
echo ""
echo "--- Claude ---"
CLAUDE_TPL="$REPO_DIR/.claude/settings.linux.json"
[[ -f "$CLAUDE_TPL" ]] || CLAUDE_TPL="$REPO_DIR/.claude/settings.json"
[[ -f "$CLAUDE_TPL" ]] || CLAUDE_TPL="$REPO_DIR/.claude/settings.macos.json"
if [[ -f "$CLAUDE_TPL" ]]; then
  echo "  template: $(basename "$CLAUDE_TPL")"
  CLAUDE_DST="$HOME/.claude/settings.json"
  mkdir -p "$HOME/.claude"
  rendered="$(sed "s|__HOME__|$HOME|g" "$CLAUDE_TPL")"
  if command -v python3 >/dev/null 2>&1; then
    if ! printf '%s' "$rendered" | python3 -c 'import json,sys; json.load(sys.stdin)' 2>/dev/null; then
      echo "  ERROR: rendered Claude settings are not valid JSON — skipping"
      note "Claude settings render produced invalid JSON; left untouched."
      rendered=""
    fi
  fi
  if [[ -n "$rendered" ]]; then
    if [[ -e "$CLAUDE_DST" || -L "$CLAUDE_DST" ]]; then
      if [[ "$rendered" == "$(cat "$CLAUDE_DST" 2>/dev/null)" ]]; then
        echo "  ~/.claude/settings.json already up to date"; rendered=""
      else
        mkdir -p "$BACKUP_DIR/.claude"
        cp -p "$CLAUDE_DST" "$BACKUP_DIR/.claude/settings.json" 2>/dev/null || true
        echo "  backed up existing -> $BACKUP_DIR/.claude/settings.json"
      fi
    fi
    if [[ -n "$rendered" ]]; then
      printf '%s\n' "$rendered" > "$CLAUDE_DST"
      echo "  wrote ~/.claude/settings.json (from $(basename "$CLAUDE_TPL"))"
    fi
  fi
else
  echo "  no Claude settings template in repo — skipping"
fi

# -- SSH config (symlink only; NEVER commit private keys) --------------------
echo ""
echo "--- SSH config ---"
if [[ -f "$REPO_DIR/ssh/config" ]]; then
  mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
  ssh_src="$REPO_DIR/ssh/config"; ssh_dst="$HOME/.ssh/config"
  if [[ -L "$ssh_dst" && "$(readlink "$ssh_dst")" == "$ssh_src" ]]; then
    echo "  ~/.ssh/config already linked"
  else
    if [[ -e "$ssh_dst" || -L "$ssh_dst" ]]; then
      mkdir -p "$BACKUP_DIR/.ssh"; mv "$ssh_dst" "$BACKUP_DIR/.ssh/config"
      echo "  backed up existing ~/.ssh/config"
    fi
    ln -s "$ssh_src" "$ssh_dst"; echo "  ~/.ssh/config -> $ssh_src"
  fi
  chmod 600 "$ssh_src" 2>/dev/null || true
else
  echo "  no ssh/config in repo — skipping (keys/secrets are never committed)"
  note "SSH: drop a non-secret ssh/config into the repo's ssh/ dir to have it linked. Keys stay out of git."
fi

# -- Switch default login shell ----------------------------------------------
echo ""
echo "--- default shell ---"
if [[ "$ZSH_OK" -ne 1 ]]; then
  echo "  zsh not available — skipping shell switch."
  note "Default shell NOT changed (zsh missing). Install zsh, then re-run."
else
  ZSH_BIN="$(command -v zsh)"
  CUR_SHELL="$(getent passwd "$USER" 2>/dev/null | cut -d: -f7)"
  CUR_SHELL="${CUR_SHELL:-$SHELL}"
  if [[ "$CUR_SHELL" == "$ZSH_BIN" ]]; then
    echo "  already zsh: $CUR_SHELL"
  else
    echo "  current login shell: $CUR_SHELL (want: $ZSH_BIN)"
    if ! grep -qx "$ZSH_BIN" /etc/shells 2>/dev/null; then
      if [[ -w /etc/shells ]]; then
        echo "$ZSH_BIN" >> /etc/shells; echo "  registered $ZSH_BIN in /etc/shells"
      elif [[ -n "$SUDO" ]]; then
        echo "$ZSH_BIN" | $SUDO tee -a /etc/shells >/dev/null 2>&1 \
          && echo "  registered $ZSH_BIN in /etc/shells (sudo)" || true
      fi
    fi
    # chsh reads its password from /dev/tty; only let it prompt interactively,
    # else bound it with timeout so a non-interactive run can't hang.
    chsh_done=0
    if [[ -t 0 ]]; then
      chsh -s "$ZSH_BIN" && chsh_done=1 || true
    elif command -v timeout >/dev/null 2>&1; then
      setsid timeout -k 2 8 chsh -s "$ZSH_BIN" </dev/null >/dev/null 2>&1 && chsh_done=1 || true
    else
      chsh -s "$ZSH_BIN" </dev/null >/dev/null 2>&1 && chsh_done=1 || true
    fi
    if [[ "$chsh_done" == "1" ]]; then
      echo "  chsh succeeded — next login will use zsh"
    else
      echo "  chsh did not change the shell. Fallback for $CUR_SHELL."
      case "$(basename "$CUR_SHELL")" in
        tcsh|csh)
          if ! grep -q "exec.*zsh" "$HOME/.login" 2>/dev/null; then
            echo "if ( -x $ZSH_BIN ) exec $ZSH_BIN -l" >> "$HOME/.login"
            echo "  appended exec-zsh to ~/.login"
            note "Login shell unchanged; added exec-zsh to ~/.login as a fallback."
          else echo "  ~/.login already has an exec-zsh line"; fi ;;
        bash|sh)
          if ! grep -q "exec.*zsh" "$HOME/.bashrc" 2>/dev/null; then
            {
              echo ""
              echo "# auto-switch to zsh on interactive login (added by install-linux.sh)"
              echo "if [[ -x \"$ZSH_BIN\" && -z \"\${ZSH_VERSION:-}\" && \$- == *i* ]]; then exec \"$ZSH_BIN\" -l; fi"
            } >> "$HOME/.bashrc"
            echo "  appended exec-zsh guard to ~/.bashrc"
            note "Login shell unchanged; added exec-zsh guard to ~/.bashrc as a fallback."
          else echo "  ~/.bashrc already has an exec-zsh line"; fi ;;
        *)
          echo "  unknown shell '$CUR_SHELL'. Switch manually: chsh -s $ZSH_BIN"
          note "Could not auto-switch shell; run: chsh -s $ZSH_BIN" ;;
      esac
    fi
  fi
fi

# -- Summary -----------------------------------------------------------------
echo ""
echo "=========================================="
echo " install complete"
echo "=========================================="
if [[ ${#NOTES[@]} -gt 0 ]]; then
  echo ""; echo "Things to note:"
  for n in "${NOTES[@]}"; do echo "  - $n"; done
fi
cat <<EOF

Next steps:
1. Start a fresh login shell (re-SSH, or open a new terminal) to land in zsh.
2. Linux uses a simple native prompt (host + path + git branch). No p10k wizard.
3. If you ever see boxes/?-marks, set your terminal font to "MesloLGS NF".
EOF
