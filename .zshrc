# =============================================================================
# .zshrc — Sumit's shell config
# Symlinked from ~/Downloads/Claude/dotfiles/.zshrc
# Edit either side, they're the same file.
# =============================================================================

# -- Powerlevel10k instant prompt (must be near the top) ---------------------
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# -- Path / env ---------------------------------------------------------------
export EDITOR="vi"
export VISUAL="$EDITOR"
export LANG="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"

# Homebrew (Apple Silicon)
if [[ -f /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -f /usr/local/bin/brew ]]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi

# -- Oh My Zsh ---------------------------------------------------------------
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"

# Behaviour tweaks
HYPHEN_INSENSITIVE="true"          # _ and - are interchangeable in completion
DISABLE_AUTO_UPDATE="false"        # let OMZ self-update
COMPLETION_WAITING_DOTS="true"     # show "..." while completion is computing
DISABLE_UNTRACKED_FILES_DIRTY="true"  # speed up status in big repos

# Plugins (installed by install.sh)
plugins=(
  git
  macos
  zsh-autosuggestions
  zsh-syntax-highlighting
  fzf
)

source $ZSH/oh-my-zsh.sh

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

# -- ls / file listing -------------------------------------------------------
# Richer BSD-ls colors. Pairs of fg/bg per file type:
#   directory, symlink, socket, pipe, executable, block sp, char sp, setuid,
#   setgid, sticky dir, writable+sticky dir. Capitals = bold.
export LSCOLORS="GxFxCxDxBxegedabagaced"
export CLICOLOR=1

# BSD-ls aliases — -h gives human-readable sizes (1.2K, 4.3M, 1.2G)
alias ls="ls -ltrFGah"           # your preferred format + human sizes
alias ll="ls -lahG"
alias la="ls -AG"
alias lt="ls -lahtrG"            # by mtime, oldest first

# If eza is installed (modern Rust ls — file-type colors, icons, git status),
# these override the BSD-ls aliases above. install.sh installs eza for you.
# Sizes are human-readable by default in eza.
if command -v eza >/dev/null 2>&1; then
  # Default ls: long format, all (incl. hidden), sorted by mtime oldest-first,
  # with icons, git status column, group dirs first, readable timestamps.
  alias ls="eza -lah --reverse --sort=modified --icons --group-directories-first --git --time-style=long-iso"
  alias ll="ls"                              # same as ls
  alias la="eza -a --icons --group-directories-first"   # short grid, all
  alias lt="eza --tree --icons --level=3"    # tree view
  alias lg="eza -lah --icons --group-directories-first --git --time-style=long-iso"  # long, name-sorted
  alias tree="eza --tree --icons --level=3"
fi

# -- cd with directory history -----------------------------------------------
# Every cd call is recorded (deduped, most-recent-first) in ~/.cd_history.
# cd -        show last 10 dirs as a numbered menu; type a number to jump
# cd --       fuzzy-search full history with fzf (type to filter, Enter to jump)
# cd <path>   works exactly like normal cd
# cd          goes home, like normal

CDHISTFILE="$HOME/.cd_history"   # persisted across sessions, survives reboots
CDHISTSIZE=50                    # how many entries to keep on disk

cd() {
  local dest

  # ---- cd - : numbered menu of last 10 dirs --------------------------------
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

  # ---- cd -- : fzf fuzzy search over full history --------------------------
  elif [[ "$1" == "--" ]]; then
    if ! command -v fzf >/dev/null 2>&1; then
      echo "fzf not found — install with: brew install fzf" >&2; return 1
    fi
    if [[ ! -s "$CDHISTFILE" ]]; then
      echo "cd history is empty" >&2; return 1
    fi
    dest=$(cat "$CDHISTFILE" | fzf --prompt="cd > " --height=15 --reverse \
           --preview='ls -1 {} 2>/dev/null | head -20' \
           --preview-window=right:40%:wrap)
    [[ -z "$dest" ]] && return 0   # user hit Esc

  # ---- normal cd -----------------------------------------------------------
  else
    dest="${1:-$HOME}"
  fi

  # Resolve and jump
  builtin cd "$dest" || return $?

  # Record new cwd — skip $HOME (too noisy), deduplicate, trim to CDHISTSIZE
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

# Auto-cd to project dirs
# Note: don't use `claude` here — it conflicts with the Claude Code CLI binary.
alias cw="cd ~/Downloads/Claude"               # cw = "Claude workspace"
alias skills="cd ~/Downloads/Claude/claude-skills"
alias proj="cd ~/Downloads/Claude/claude-projects"
alias nvproj="cd ~/Downloads/Claude/claude-nvidia-projects"
alias dots="cd ~/Downloads/Claude/dotfiles"

# -- Git shortcuts (most also in ~/.gitconfig as `git X` aliases) ------------
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
alias path='echo -e ${PATH//:/\\n}'                     # one entry per line
alias reload="source ~/.zshrc && echo 'reloaded ~/.zshrc'"
alias claudelog="tail -f ~/Downloads/Claude/sync.log"
alias claudesync="~/Downloads/Claude/sync.sh && echo 'synced'"

# -- Functions ---------------------------------------------------------------
# mkdir + cd in one go
mkcd() { mkdir -p "$1" && cd "$1"; }

# Extract anything based on extension
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

# -- nvsave: save an image from build.nvidia.com's JSON tab on clipboard -----
# Usage:
#   1. On build.nvidia.com, click JSON tab and Cmd+A, Cmd+C
#   2. In terminal:  nvsave my-image-name
#      (no extension needed — JPEG or PNG is auto-detected)
# Saves to current directory and opens in Preview. Also prints the seed
# so you can reproduce the exact image later.
nvsave() {
  if [[ -z "$1" ]]; then
    echo "usage: nvsave <basename>   (no extension)" >&2; return 1
  fi
  # Build the python script as a string (single-quoted, so all chars are
  # literal). Avoids f-strings to dodge Python 3.10 quoting quirks.
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
  open "$file"
}

# -- FZF (fuzzy finder) integration ------------------------------------------
# install.sh runs `$(brew --prefix)/opt/fzf/install` which sets these up,
# but having the source guarded here makes things robust.
[[ -f ~/.fzf.zsh ]] && source ~/.fzf.zsh

# -- Powerlevel10k user config ----------------------------------------------
# Created on first run by `p10k configure`. Until you run that, p10k uses
# its default style.
[[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh

# -- Prompt overrides (win over anything p10k's wizard set) -----------------
# Always show the full, literal directory path:
#   - no truncation (full /a/b/c/d, never /a/.../d)
#   - no ~ abbreviation (literal /Users/subansal/..., not ~/...)
typeset -g POWERLEVEL9K_SHORTEN_STRATEGY=none
typeset -g POWERLEVEL9K_SHORTEN_DIR_LENGTH=0
typeset -g POWERLEVEL9K_DIR_MAX_LENGTH=0
typeset -g POWERLEVEL9K_DIR_MIN_COMMAND_COLUMNS=0
typeset -g POWERLEVEL9K_DIR_MIN_COMMAND_COLUMNS_PCT=0
# %d = zsh prompt expansion for full cwd without ~ substitution
typeset -g POWERLEVEL9K_DIR_CONTENT_EXPANSION='%d'
