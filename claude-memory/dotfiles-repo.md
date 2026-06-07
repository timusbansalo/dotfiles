---
name: dotfiles-repo
description: "Sumit's portable dotfiles repo, its single installer, and cross-machine/NVIDIA workflow"
metadata: 
  node_type: memory
  type: project
  originSessionId: 16fc523d-f1cf-4090-81b7-80b261e20d7f
---

Dotfiles repo at `~/dotfiles` (origin `github.com/timusbansalo/dotfiles`, branch `main`). **The repo's `CLAUDE.md` is the source of truth** for preferences, the NVIDIA package policy, and how to enhance things — read it first when working here or replicating the setup elsewhere. See [[user-preferences]] and [[nvidia-environments]].

Single entry point: **`./install.sh`** detects the OS and dispatches to `install-macos.sh` (Homebrew + OMZ + Powerlevel10k) or `install-linux.sh`. The user must never need to remember which script to run — extend the dispatcher, don't add a second command.

`install-linux.sh` is portable: detects distro, package manager (apt/dnf/yum/zypper/pacman/apk/brew), sudo capability (root/nopasswd/password/noprompt/none), and NVIDIA env (standard|nvidia-vm|omnistation) with a live `github.com` probe (`NV_GITHUB_OK`; override `NV_ENV=`/`GH_OK=`). On Omnistation it skips all github clones, installs zsh plugins + tools via apt (+ cargo/Artifactory fallback), pulls the Nerd Font from raw.githubusercontent, and uses the simple native prompt.

`.zshrc` is one shared OS-aware file: macOS = Powerlevel10k; Linux = simple native prompt with hostname via `vcs_info` (no p10k). Linux `ls` uses GNU `--color` (not BSD `-G`/`LSCOLORS`). When OMZ is absent it sources apt `zsh-autosuggestions`/`zsh-syntax-highlighting` from `/usr/share`. Claude settings are per-OS `.claude/settings.{macos,linux}.json` templates rendered (not symlinked) into `~/.claude/settings.json` via a `__HOME__` token. SSH: only a non-secret `ssh/config` is committed; keys are gitignored.

Versioning: every script/config carries `# dotfiles-version: X.Y.Z` (canonical `DOTFILES_VERSION` in install.sh); install.sh runs a preflight that aborts if a required script is missing or version-mismatched (catches half-synced copies) — bump all markers together. `nvidia-artifactory.sh` wires pip/npm (documents cargo) to NVIDIA Artifactory, auto-run by install-linux.sh on NVIDIA envs (`NV_ARTIFACTORY=0` to skip). `.zshrc` shows a `whereami` login banner (host + env + restrictions). SSH config committed at `ssh/config` (portable `~` paths, keys gitignored).

Sync = scp between machines + `git push` from a github-reachable box (Mac/NVIDIA VM). **Cannot push to personal GitHub from Omnistation.** Both installers are idempotent and `set -euo pipefail` — see [[bash-set-e-pitfalls]]. This dev box's egress quirks: [[dev-box-github-egress]].
