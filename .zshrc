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
alias ls="ls -G"                 # color
alias ll="ls -lah"
alias la="ls -A"
alias lt="ls -lahtr"             # by mtime, oldest first

# -- Navigation --------------------------------------------------------------
alias ..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."

# Auto-cd to project dirs
alias claude="cd ~/Downloads/Claude"
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

# -- FZF (fuzzy finder) integration ------------------------------------------
# install.sh runs `$(brew --prefix)/opt/fzf/install` which sets these up,
# but having the source guarded here makes things robust.
[[ -f ~/.fzf.zsh ]] && source ~/.fzf.zsh

# -- Powerlevel10k user config ----------------------------------------------
# Created on first run by `p10k configure`. Until you run that, p10k uses
# its default style.
[[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh
