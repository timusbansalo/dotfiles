# CLAUDE.md — read this first

This file is for **Claude (and other AI coding agents)**. It captures how Sumit
(`subansal@nvidia.com`) likes his environment set up, what he dislikes, and the
constraints of the machines this repo runs on. Read it before changing anything
here, and apply the same preferences when enhancing dotfiles on a new machine or
in a separate project.

## The golden rule
**One command, everywhere:** `./install.sh`. The user should never have to
remember which script to run. `install.sh` detects the OS and dispatches to
`install-macos.sh` or `install-linux.sh`. Keep it that way — if you add a
platform, extend the dispatcher; don't add a second thing to remember.

Everything must be **idempotent** (safe to re-run) and **never hang** in a
non-interactive run. This repo is `set -euo pipefail` throughout — see the
"bash gotchas" section.

## Versioning & preflight
Every script/config carries a `# dotfiles-version: X.Y.Z` marker (vimscript uses
`"`; JSON has none — it can't hold comments). The canonical version is
`DOTFILES_VERSION` in `install.sh`. On startup `install.sh` runs a **preflight**
that verifies the scripts it depends on (`install-<os>.sh`, `.zshrc`, and
`nvidia-artifactory.sh` when present) exist AND carry the matching version —
aborting loudly on a missing file or version mismatch (catches half-synced
copies). When you change scripts, bump `DOTFILES_VERSION` and every marker
together.

## Login welcome banner
`.zshrc` defines `whereami` and shows it once on interactive login shells: it
prints the hostname, the environment (macOS / NVIDIA VM / Omnistation), and the
restrictions (e.g. "no open internet · github blocked · apt + Artifactory only").
It's printed BEFORE the p10k instant-prompt block (console output after it warns).
Run `whereami` anytime.

## Environments this repo runs on
1. **macOS** (Apple Silicon) — primary workstation. Homebrew. Rich prompt
   (Powerlevel10k). Full internet.
2. **NVIDIA Linux VM** — has both internal and external internet; can git-sync
   to **personal GitHub** and **NVIDIA GitLab** (`gitlab-master.nvidia.com`).
3. **NVIDIA Omnistation sandbox** — locked down. **No open internet**; outbound
   traffic goes through an egress ACL allowlist. Detected by hostname `omni-*`
   and/or `SSH_SESSION_WEBPROXY_ADDR` (Teleport). `github.com`=503,
   `api.github.com`=403, but `raw.githubusercontent.com`/`objects.githubusercontent.com`=200.
   **No personal-git access** (can't push to personal GitHub from here).

The installer auto-detects these (`NV_ENV` = standard | nvidia-vm | omnistation)
and does a live `github.com` reachability probe (`NV_GITHUB_OK`). Override with
`NV_ENV=...` or `GH_OK=0|1`.

## Omnistation / NVIDIA package policy (do NOT violate)
On Omnistation, install software in this strict order, and **never** proxy or
tunnel around the ACL (it is monitored, and prohibited):
1. **apt** first — `sudo apt update && sudo apt install -y <pkg>` (internal
   mirror is allowlisted; most tools incl. eza, fzf, ripgrep, jq, gh are here).
2. **Language package managers via NVIDIA Artifactory** (not in apt):
   - pip: index `https://urm.nvidia.com/artifactory/api/pypi/nv-shared-pypi/simple`
     (new host: `https://artifactory.nvidia.com/...`).
   - npm: registry `https://urm.nvidia.com/artifactory/api/npm/npm/`.
   - cargo: `cargo install <crate>` (Artifactory-backed).
3. **artifactory-download `<url>` `<out>`** for raw binaries when nothing else fits.
4. If still impossible (tool only on a non-NVIDIA GitHub org): **STOP and ask the
   human.** Options are: tsh scp from laptop, mirror into NVIDIA GitLab, or file
   an ACL exception. Do not work around it.

Consequence baked into the installer: on Omnistation it **skips github clones**
(Oh My Zsh, Powerlevel10k, plugin repos, fzf clone) and uses apt packages +
the simple native prompt instead. The Nerd Font is fetched from
`raw.githubusercontent.com` (allowed).

## Shell / prompt preferences
- **Prompt:** keep it **simple, small, and with the hostname**. The user does
  NOT like a heavy/complex prompt on Linux.
  - macOS: Powerlevel10k (his `~/.p10k.zsh`, full literal cwd, no `~` abbrev).
  - Linux: a **native zsh prompt, NO p10k dependency** (works on Omnistation):
    `host  ~/path  (git-branch)  ❯` via built-in `vcs_info`. Defined in `.zshrc`.
  - If he wants the *exact* macOS look on Linux, he must share `~/.p10k.zsh`;
    don't guess it.
- **`ls` must work on every OS.** macOS = BSD `ls` (`-G` + `LSCOLORS`); Linux =
  GNU `ls` (`--color=auto`, `LSCOLORS` ignored, `-G` means no-group — never use
  BSD flags on Linux). `.zshrc` branches on `uname`. If `eza` is present it
  takes over (icons only on macOS — Linux may lack a Nerd Font).
- Oh My Zsh is optional on Linux. When absent (Omnistation), `.zshrc` sources
  the apt `zsh-autosuggestions` / `zsh-syntax-highlighting` from `/usr/share`
  (syntax-highlighting MUST be sourced last).
- Editor is `vi`. Big shared/deduped history. Custom `cd` with history menu +
  fzf. `nvsave` clipboard→image helper (uses pbpaste/open on mac, xclip/xdg-open
  on Linux).

## SSH
- The installer symlinks `~/.ssh/config` from `ssh/config` in the repo **if it
  exists** (perms 700 dir / 600 file).
- **NEVER commit private keys or secrets.** `.gitignore` blocks `ssh/` key
  material; only a non-secret `config` belongs in git. Keys move between
  machines out-of-band (tsh scp / manual), never through this repo.

## Git / sync workflow
- Repo origin: `github.com/timusbansalo/dotfiles` (personal). Branch `main`.
- The user syncs by **scp between machines + `git push`** from a box that has
  personal-GitHub access (Mac or NVIDIA VM). **From Omnistation you cannot push
  to personal GitHub** — commit locally and push elsewhere, or mirror to NVIDIA
  GitLab.
- Always end commit messages with the Co-Authored-By trailer for Claude.

## Repo layout
- `install.sh` — OS-detecting dispatcher + version preflight (the only entry point).
- `install-macos.sh` — Homebrew + OMZ + p10k + symlinks + Vim + Claude.
- `install-linux.sh` — portable Linux installer (distro/pkgmgr/sudo/NVIDIA aware).
- `nvidia-artifactory.sh` — wires pip/npm (documents cargo) to NVIDIA Artifactory;
  auto-run by `install-linux.sh` on NVIDIA envs (skip with `NV_ARTIFACTORY=0`).
- `ssh/config` — non-secret SSH config (gitlab + the linux VM), `~`-relative
  IdentityFile paths so it's portable; symlinked to `~/.ssh/config`.
- `sync-from-omnistation.sh` — RUN ON THE MAC: tsh-scp the repo from Omnistation,
  verify the transfer, fast-forward the Mac repo, push to GitHub, sync memory.
- `claude-memory/` — git-synced copy of the agent's memory files (this file
  `CLAUDE.md` is the canonical, auto-read source of truth; keep both updated).
- `.zshrc` — single shared, OS-aware shell config.
- `.gitconfig`, `.gitignore_global`, `.vimrc` (vim-plug), `macos-defaults.sh`.
- `.claude/settings.macos.json` + `.claude/settings.linux.json` — per-OS Claude
  permission templates using a `__HOME__` token, rendered into
  `~/.claude/settings.json` at install time (NOT symlinked — that's what makes
  one repo portable across usernames/homes).
- `uninstall.sh`, `README.md`, this `CLAUDE.md`.

## Bash gotchas that have bitten this repo (under `set -euo pipefail`)
- A bare helper call returning non-zero aborts the script → "best-effort"
  helpers must `return 0` (notes record misses instead).
- `var="$(cmd | pipe)"` aborts if any stage fails under `pipefail` (e.g.
  `curl -f` hitting 403) → wrap with `|| true`.
- A `for` loop whose last command is `[[ test ]] && action` can trip `set -e`
  → use `if [[ test ]]; then ...; fi`.
- `chsh` reads the password from `/dev/tty`; gate on `[[ -t 0 ]]` and otherwise
  run `setsid timeout -k 2 8 chsh ...` so it can't hang.
- Always `DEBIAN_FRONTEND=noninteractive` (+ `NEEDRESTART_MODE=a`) for apt.

## How to enhance (when the user asks for more)
- Re-read this file first; match these preferences and constraints.
- Keep the single-entry-point and idempotency invariants.
- Test Linux changes in an isolated `$HOME` + repo copy before touching the
  real environment; `zsh -n .zshrc` and `bash -n install-linux.sh`.
- Update this file with any new learning, and commit it.
