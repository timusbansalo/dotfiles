---
name: dev-box-github-egress
description: This Linux dev box blocks github.com/api.github.com but allows raw.githubusercontent.com
metadata: 
  node_type: memory
  type: reference
  originSessionId: 16fc523d-f1cf-4090-81b7-80b261e20d7f
---

On this Ubuntu dev box (`/home/subansal`, host omni-lsn-*), GitHub egress is partially blocked:

- `github.com` (git clone, release downloads) → HTTP 503
- `api.github.com` → HTTP 403
- `raw.githubusercontent.com` → HTTP 200 (works)

So scripts that `git clone` from github.com (Oh My Zsh, Powerlevel10k, zsh plugins, fzf) or download GitHub release tarballs (eza/ripgrep binaries) can't complete a real run here. `apt` package installs work fine. When testing installers like [[dotfiles-repo]] here, pre-seed the clone targets (e.g. `~/.oh-my-zsh`, p10k/plugin dirs) so idempotent "already installed" branches are taken, and treat clone/download failures as environment limits, not script bugs.
