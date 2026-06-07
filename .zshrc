# =============================================================================
# .zshrc — Sumit's shell config (portable: macOS + Linux incl. NVIDIA VMs)
# Symlinked from the dotfiles repo. Edit either side, they're the same file.
#
# Design: macOS uses Oh My Zsh + Powerlevel10k (the rich prompt). Linux uses a
# simple native prompt with the hostname and NO p10k dependency, so it also
# works on NVIDIA Omnistation sandboxes where github.com is blocked and OMZ/p10k
# cannot be cloned. See ~/dotfiles/CLAUDE.md for the full rationale.
# =============================================================================

# Cache uname once.
_OS="$(uname -s)"

# -- Powerlevel10k instant prompt (macOS; harmless no-op elsewhere) ----------
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# -- Path / env ---------------------------------------------------------------
export EDITOR="vi"
export VISUAL="$EDITOR"
export LANG="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"
# pip --user / cargo / npm-global binaries land here on Linux
[[ -d "$HOME/.local/bin" ]] && export PATH="$HOME/.local/bin:$PATH"

# Homebrew (Apple Silicon / Intel)
if [[ -f /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -f /usr/local/bin/brew ]]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi

# -- Oh My Zsh (when present) / plugin fallback (when not) -------------------
export ZSH="$HOME/.oh-my-zsh"

# Behaviour tweaks (apply regardless of OMZ)
HYPHEN_INSENSITIVE="true"             # _ and - interchangeable in completion
DISABLE_AUTO_UPDATE="false"           # let OMZ self-update
COMPLETION_WAITING_DOTS="true"        # show "..." while completing
DISABLE_UNTRACKED_FILES_DIRTY="true"  # speed up status in big repos

if [[ -d "$ZSH" ]]; then
  # Oh My Zsh is installed (macOS, or a Linux box with github access).
  if [[ "$_OS" == "Darwin" ]]; then
    ZSH_THEME="powerlevel10k/powerlevel10k"   # rich prompt on macOS
    plugins=(git macos zsh-autosuggestions zsh-syntax-highlighting fzf)
  else
    ZSH_THEME=""                              # Linux: simple native prompt below
    plugins=(git zsh-autosuggestions zsh-syntax-highlighting fzf)
  fi
  source "$ZSH/oh-my-zsh.sh"
else
  # No Oh My Zsh (e.g. NVIDIA Omnistation can't clone github). Source the
  # apt-installed autosuggestions plugin directly. Syntax highlighting must be
  # sourced LAST, so it's done at the very end of this file.
  for _f in /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh \
            /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh; do
    [[ -r "$_f" ]] && { source "$_f"; break; }
  done
  autoload -Uz compinit && compinit -u 2>/dev/null   # basic completion
fi

# -- History (big, shared across tabs, deduped) -------------------------------
HISTFILE="$HOME/.zsh_history"
HISTSIZE=100000
SAVEHIST=100000
setopt INC_APPEND_HISTORY       # write to history immediately, not at exit
setopt SHARE_HISTORY            # new tabs see commands from other tabs
setopt HIST_IGNORE_DUPS         # don't store a command if same as previous
setopt HIST_IGNORE_ALL_DUPS     # remove older duplicates entirely
setopt HIST_IGNORE_SPACE        # commands starting with space don't get saved
setopt HIST_REDUCE_BLANKS       # trim extra whitespace
setopt HIST_VERIFY              # don't auto-execute on history expansion

# -- ls / file listing (OS-aware) --------------------------------------------
if [[ "$_OS" == "Darwin" ]]; then
  # BSD ls: -G enables color, LSCOLORS sets the palette.
  export LSCOLORS="GxFxCxDxBxegedabagaced"
  export CLICOLOR=1
  alias ls="ls -ltrFGah"          # preferred format + human sizes
  alias ll="ls -lahG"
  alias la="ls -AG"
  alias lt="ls -lahtrG"           # by mtime, oldest first
else
  # GNU ls: --color=auto (LSCOLORS is ignored by GNU ls; -G means no-group).
  alias ls="ls -ltrFah --color=auto --group-directories-first"
  alias ll="ls -lah  --color=auto --group-directories-first"
  alias la="ls -A    --color=auto"
  alias lt="ls -lahtr --color=auto"
fi

# If eza is installed (modern Rust ls), it overrides the aliases above.
# Icons need a Nerd Font, which we have on macOS but not necessarily on Linux
# (Omnistation can't download it), so only request icons on macOS.
if command -v eza >/dev/null 2>&1; then
  if [[ "$_OS" == "Darwin" ]]; then _EZA_ICONS="--icons"; else _EZA_ICONS=""; fi
  alias ls="eza -lah --reverse --sort=modified $_EZA_ICONS --group-directories-first --git --time-style=long-iso"
  alias ll="ls"
  alias la="eza -a $_EZA_ICONS --group-directories-first"
  alias lt="eza --tree $_EZA_ICONS --level=3"
  alias lg="eza -lah $_EZA_ICONS --group-directories-first --git --time-style=long-iso"
  alias tree="eza --tree $_EZA_ICONS --level=3"
fi

# -- cd with directory history -----------------------------------------------
# cd -   numbered menu of last 10 dirs;  cd --  fzf fuzzy search;  cd <path> normal
CDHISTFILE="$HOME/.cd_history"
CDHISTSIZE=50

cd() {
  local dest

  if [[ "$1" == "-" ]]; then
    if [[ ! -s "$CDHISTFILE" ]]; then
      echo "cd history is empty" >&2; return 1
    fi
    local -a entries
    entries=("${(@f)$(head -10 "$CDHISTFILE")}")
    echo ""
    local i=1
    for entry in "${entries[@]}"; do
      printf "  %2d  %s\n" "$i" "$entry"
      (( i++ ))
    done
    echo ""
    printf "Enter number (1–%d), or q to cancel: " "${#entries[@]}"
    local choice
    read -r choice
    [[ "$choice" == "q" || -z "$choice" ]] && return 0
    if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#entries[@]} )); then
      dest="${entries[$choice]}"
    else
      echo "Invalid selection." >&2; return 1
    fi

  elif [[ "$1" == "--" ]]; then
    if ! command -v fzf >/dev/null 2>&1; then
      echo "fzf not found — install with apt/brew" >&2; return 1
    fi
    if [[ ! -s "$CDHISTFILE" ]]; then
      echo "cd history is empty" >&2; return 1
    fi
    dest=$(cat "$CDHISTFILE" | fzf --prompt="cd > " --height=15 --reverse \
           --preview='ls -1 {} 2>/dev/null | head -20' \
           --preview-window=right:40%:wrap)
    [[ -z "$dest" ]] && return 0

  else
    dest="${1:-$HOME}"
  fi

  builtin cd "$dest" || return $?

  local cwd="$PWD"
  if [[ "$cwd" != "$HOME" ]]; then
    local tmpfile
    tmpfile=$(mktemp)
    { echo "$cwd"; [[ -f "$CDHISTFILE" ]] && grep -Fxv "$cwd" "$CDHISTFILE"; } \
      | head -"$CDHISTSIZE" > "$tmpfile"
    mv "$tmpfile" "$CDHISTFILE"
  fi
}

# -- Navigation --------------------------------------------------------------
alias ..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."

# Project shortcuts. macOS keeps the work under ~/Downloads/Claude; on Linux the
# repos live directly under $HOME. `dots` always points at this dotfiles repo.
if [[ "$_OS" == "Darwin" ]]; then
  alias cw="cd ~/Downloads/Claude"
  alias skills="cd ~/Downloads/Claude/claude-skills"
  alias proj="cd ~/Downloads/Claude/claude-projects"
  alias nvproj="cd ~/Downloads/Claude/claude-nvidia-projects"
  alias dots="cd ~/Downloads/Claude/dotfiles"
else
  alias cw="cd ~/claude 2>/dev/null || cd ~"
  alias dots="cd ~/dotfiles"
fi

# -- Git shortcuts -----------------------------------------------------------
alias g="git"
alias gs="git status -sb"
alias gco="git checkout"
alias gp="git push"
alias gpl="git pull"
alias gl="git log --oneline --graph --decorate -20"
alias gla="git log --oneline --graph --decorate --all -30"
alias gd="git diff"
alias gds="git diff --staged"
alias gst="git stash"
alias gcm="git commit -m"
alias gca="git commit --amend --no-edit"
alias gb="git branch"
alias gr="git rebase"

# -- Misc niceties -----------------------------------------------------------
alias path='echo -e ${PATH//:/\\n}'
alias reload="source ~/.zshrc && echo 'reloaded ~/.zshrc'"

# -- Functions ---------------------------------------------------------------
mkcd() { mkdir -p "$1" && cd "$1"; }

extract() {
  if [[ -f "$1" ]]; then
    case "$1" in
      *.tar.bz2)   tar xjf "$1"   ;;
      *.tar.gz)    tar xzf "$1"   ;;
      *.bz2)       bunzip2 "$1"   ;;
      *.gz)        gunzip "$1"    ;;
      *.tar)       tar xf  "$1"   ;;
      *.tbz2)      tar xjf "$1"   ;;
      *.tgz)       tar xzf "$1"   ;;
      *.zip)       unzip   "$1"   ;;
      *.7z)        7z x    "$1"   ;;
      *)           echo "Don't know how to extract '$1'" ;;
    esac
  else
    echo "'$1' is not a valid file"
  fi
}

# clip helpers — pbcopy/pbpaste on macOS, xclip/xsel on Linux
if [[ "$_OS" != "Darwin" ]] && ! command -v pbcopy >/dev/null 2>&1; then
  if command -v xclip >/dev/null 2>&1; then
    alias pbcopy='xclip -selection clipboard'
    alias pbpaste='xclip -selection clipboard -o'
  elif command -v xsel >/dev/null 2>&1; then
    alias pbcopy='xsel --clipboard --input'
    alias pbpaste='xsel --clipboard --output'
  fi
fi

# nvsave: save an image from build.nvidia.com's JSON tab on the clipboard.
nvsave() {
  if [[ -z "$1" ]]; then
    echo "usage: nvsave <basename>   (no extension)" >&2; return 1
  fi
  local script='
import sys, json, base64
name = sys.argv[1]
data = sys.stdin.read()
try:
    d = json.loads(data)
except Exception:
    sys.stderr.write("ERROR: clipboard does not contain valid JSON\n"); sys.exit(1)
art = d.get("artifacts", [{}])[0]
b64 = art.get("base64") or art.get("image", "").split(",")[-1]
if not b64:
    sys.stderr.write("ERROR: no base64 image field found in JSON\n"); sys.exit(1)
raw = base64.b64decode(b64)
ext = "jpg" if raw[:3] == b"\xff\xd8\xff" else "png"
path = name + "." + ext
with open(path, "wb") as f:
    f.write(raw)
print(path + "|" + str(art.get("seed", "unknown")))
'
  local out
  out=$(pbpaste | python3 -c "$script" "$1") || return 1
  local file="${out%%|*}"
  local seed="${out##*|}"
  echo "saved $file  (seed: $seed)"
  if command -v open >/dev/null 2>&1; then open "$file"
  elif command -v xdg-open >/dev/null 2>&1; then xdg-open "$file" 2>/dev/null; fi
}

# -- FZF (fuzzy finder) integration ------------------------------------------
[[ -f ~/.fzf.zsh ]] && source ~/.fzf.zsh

# -- Prompt ------------------------------------------------------------------
if [[ "$_OS" == "Darwin" ]]; then
  # Powerlevel10k user config (created by `p10k configure`).
  [[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh
  # Always show the full literal cwd (no truncation, no ~ abbreviation).
  typeset -g POWERLEVEL9K_SHORTEN_STRATEGY=none
  typeset -g POWERLEVEL9K_SHORTEN_DIR_LENGTH=0
  typeset -g POWERLEVEL9K_DIR_MAX_LENGTH=0
  typeset -g POWERLEVEL9K_DIR_MIN_COMMAND_COLUMNS=0
  typeset -g POWERLEVEL9K_DIR_MIN_COMMAND_COLUMNS_PCT=0
  typeset -g POWERLEVEL9K_DIR_CONTENT_EXPANSION='%d'
else
  # Simple, small Linux prompt with the hostname. No p10k dependency, so it
  # works everywhere including NVIDIA Omnistation. Git branch via zsh's
  # built-in vcs_info (no plugin needed).  Looks like:  host  ~/path (branch) ❯
  autoload -Uz vcs_info
  zstyle ':vcs_info:*' enable git
  zstyle ':vcs_info:git:*' formats ' (%b)'
  precmd_functions+=(vcs_info)
  setopt PROMPT_SUBST
  PROMPT='%F{green}%m%f %F{cyan}%~%f%F{yellow}${vcs_info_msg_0_}%f %(!.#.❯) '
fi

# -- Linux-local overrides (sourced if present; written by install-linux.sh) -
[[ -f "$HOME/.zshrc.linux-local" && "$_OS" == "Linux" ]] && source "$HOME/.zshrc.linux-local"

# -- zsh-syntax-highlighting (MUST be last) — only when OMZ didn't load it ----
if [[ ! -d "$ZSH" ]]; then
  for _f in /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh \
            /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh; do
    [[ -r "$_f" ]] && { source "$_f"; break; }
  done
fi
