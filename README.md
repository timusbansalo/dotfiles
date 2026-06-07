# dotfiles

Cross-platform terminal config for **macOS and Linux** (including NVIDIA VMs and
Omnistation sandboxes). One installer, OS-aware `.zshrc`, `.gitconfig`, `.vimrc`,
and per-OS Claude settings.

> **AI agents:** read [`CLAUDE.md`](CLAUDE.md) first — it documents preferences,
> the NVIDIA/Omnistation package policy, and how to enhance things.

## Install — one command, any machine

```bash
./install.sh
```

That's it. `install.sh` detects the OS and runs the right installer; you never
have to remember which one. It first runs a **preflight** that checks the
scripts it needs are present and at the same `# dotfiles-version:` (a
half-synced copy fails loudly instead of doing something weird).

| Entry | Runs | Notes |
|-------|------|-------|
| `install.sh` | dispatcher + version preflight | detects macOS vs Linux |
| `install-macos.sh` | Homebrew + OMZ + Powerlevel10k + plugins + font + symlinks + Vim + Claude | |
| `install-linux.sh` | distro/pkgmgr/sudo/NVIDIA-aware setup | apt + Artifactory on Omnistation; native prompt; no github required |
| `nvidia-artifactory.sh` | wires pip/npm (documents cargo) to NVIDIA Artifactory | auto-run on NVIDIA envs; `NV_ARTIFACTORY=0` to skip |

On login you get a one-line banner (`whereami`) showing the machine, environment,
and its restrictions. Everything is idempotent and backs up anything it replaces
to `~/.dotfiles-backup-<timestamp>/`.

## What's here

| File | Symlinks / renders to | Purpose |
|------|----------------------|---------|
| `.zshrc` | `~/.zshrc` | OS-aware shell config (OMZ on mac, native prompt on Linux) |
| `.gitconfig` | `~/.gitconfig` | global git config + aliases |
| `.gitignore_global` | `~/.gitignore_global` | per-repo ignores |
| `.vimrc` | `~/.vimrc` | vim-plug config (bootstrapped + `:PlugInstall` by the installer) |
| `.claude/settings.{macos,linux}.json` | `~/.claude/settings.json` | per-OS Claude permissions, rendered (not symlinked) with this host's `$HOME` |
| `ssh/config` *(optional)* | `~/.ssh/config` | non-secret SSH config — **keys are never committed** |
| `macos-defaults.sh` | — | optional macOS Finder/Dock/keyboard tweaks |
| `uninstall.sh` | — | remove the symlinks |

## Prompt

- **macOS:** Powerlevel10k (`p10k configure` → `~/.p10k.zsh`).
- **Linux:** a simple native prompt with the hostname — `host  ~/path  (branch)  ❯`
  — no Powerlevel10k dependency, so it works even where github is blocked.

## Sync

Origin is `github.com/timusbansalo/dotfiles`. Edit the symlink in `~` or the file
in the repo — same file. Commit and push from a machine with personal-GitHub
access (Mac or NVIDIA VM). **Omnistation cannot push to personal GitHub** — push
from elsewhere or mirror to NVIDIA GitLab. See `CLAUDE.md`.

## Uninstall

```bash
./uninstall.sh                 # removes symlinks
```
Backups of replaced files live at `~/.dotfiles-backup-<timestamp>/`.
