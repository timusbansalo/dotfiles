---
name: user-preferences
description: How Sumit likes his shell/tooling/install setup — apply across machines and projects
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 16fc523d-f1cf-4090-81b7-80b261e20d7f
---

Cross-project preferences Sumit has stated (apply these when enhancing dotfiles or any environment setup, on any machine):

**Why:** he runs the same configs across macOS, an NVIDIA Linux VM, and NVIDIA Omnistation sandboxes, and wants a frictionless, consistent experience without per-machine fiddling.

**How to apply:**
- **One command to set up a machine** — never make him remember which script to run. A single entry point that auto-detects the environment and does the right thing.
- **Simple, small prompt with the hostname.** He dislikes complex/heavy prompts. On Linux prefer a lightweight native prompt over Powerlevel10k (which also can't install on Omnistation). macOS keeps p10k. Don't invent his exact p10k look — ask him to share `~/.p10k.zsh` if exact parity is wanted.
- **Things must actually work per-OS** — e.g. `ls` colors/aliases must use GNU flags on Linux, BSD on macOS; he notices when they're broken.
- **Idempotent, never-hang scripts**; test changes in isolation before touching the real environment.
- **Save learnings durably and commit them** — he wants a committed `CLAUDE.md`-style file in the repo so future agents (new machine / new project) read his preferences and constraints and enhance accordingly. Keep it updated. See [[dotfiles-repo]].
- **Never proxy/tunnel around NVIDIA egress ACLs** — follow the sanctioned package policy (apt → Artifactory → ask a human). See [[nvidia-environments]].
- He has used `--dangerously-skip-permissions` / a broad `permissions.allow` allowlist to avoid repeated Claude permission prompts, and gets annoyed by repeated clarifying questions — prefer sensible defaults + proceeding over asking.
