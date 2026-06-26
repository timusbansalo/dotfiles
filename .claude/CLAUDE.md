# Personal Claude instructions

## Omnistation MCP — company tools via sandbox

An MCP server runs on the Omnistation sandbox (`omni-lsn-talxl`, alias `omnistation`) and exposes 9 NVIDIA internal tools. It is **globally registered** (`--scope user`) and available in every Claude session as the `omnistation` MCP server.

**Use these tools directly** — do not ask the user to look things up manually:

| `mcp__omnistation__*` tool | What it accesses |
|---|---|
| `nvbugs` | NVBugs bug tracker |
| `confluence` | NVIDIA Confluence |
| `slack` | Slack |
| `glean` | Glean enterprise search |
| `outlook` | Outlook email |
| `meeting` | Teams meeting transcripts / recaps |
| `onenote` | OneNote |
| `nvspecs` | NVIDIA product specs |
| `nvinfo` | NVIDIA org / people info |
| `omni_shell` | Raw shell on the sandbox (fallback for anything else) |

**Infrastructure:**
- SSH alias `omnistation` → `omni-lsn-talxl.ext-nv-prd-apps.teleport.sh` (port 3022, Teleport)
- MCP server: `~/mcp-server.py` on sandbox, venv at `~/mcp-venv/` (mcp 1.27.2)
- Health check: `ssh omnistation '~/mcp-health.sh'` — shows ✓/✗ for all 9 tools
- All 9 tools authenticated as of 2026-06-07

**Re-auth if a tool shows ✗:**
- `nvbugs` / `confluence`: API tokens in `~/.ai-pim-utils/tokens.toml` (long-lived, rarely expire)
- `slack` / `glean`: `auth init` → open URL → `auth complete '<url>'` (I can drive this)
- `outlook` / `meeting` / `onenote` / `nvinfo`: device-code flow — user must SSH in interactively
- `nvspecs`: auto-auth, no action needed

**Dotfiles:** MCP server committed at `~/dotfiles/omni-mcp-server.py`; SSH alias in `~/dotfiles/ssh/config`.

## Standing P0 reminders (check at session start when working on these projects)

- **SCG Domain Supervisor** (`~/Downloads/Claude/SCG-Domain-Supervisor/`, port 8000 on subansa-linux-vm): uvicorn is running in a bare tmux session — NOT under systemd --user. Will not survive a VM reboot. Fix is P0: create `~/.config/systemd/user/scg-supervisor.service` (same pattern as archdev-dashboard.service), enable it, kill the tmux session. Linger already enabled. Full instructions in project memory `scg-p0-items.md`.

- **archdev-dfp dashboard** (`~/src/archdev-programmanager/`, live at archdev-dfp.nvidia.com; deploys via GitLab CI on `v*` tags): **P0** — every program must appear on BOTH the Assignment Matrix and Schedule pages (missing: **TCX10** → add manually; **Newport** → Intel naming mismatch, investigate; program list comes from Frank's Excel → add a missing-program validator + manual-add fallback). **P1** — DFP lifecycle tracking per phase per program, scheduled via **program-specific milestone mapping** (PFNL/Tapeout-based + offset + per-program override + signoff/governance), **not** pure PON offsets. Full review feedback + backlog in the project's auto-memory (`archdev_vishruth_review.md`, `archdev_roadmap_priorities.md`) and git-synced at repo `docs/feedback/2026-06-10-vishruth-review-and-roadmap.md` + `~/dotfiles/claude-memory/archdev-dfp-dashboard.md`. Last shipped: v0.16.0 (staffing-gap feature).

## Focus tracker awareness

The user maintains a personal focus tracker at `~/Downloads/Claude/focus-tracker/`. When relevant — i.e., when the user is working on something that looks like it relates to a program (e.g., a doc that mentions a program name, a Jira ticket for a tracked program, etc.) — offer to log progress:

> "This looks like it relates to <Program X>. Want me to log it as progress (bump last_touched / add to top-3 done list)?"

To see the user's current top-3 + active programs, read:
- `~/Downloads/Claude/focus-tracker/journal/<today>.md` for top-3
- `~/Downloads/Claude/focus-tracker/programs/*.md` for active programs

Don't be intrusive — offer once, accept "no" gracefully. The user's full playbooks live at `~/Downloads/Claude/focus-tracker/CLAUDE.md` if you need them.
