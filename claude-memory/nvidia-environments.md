---
name: nvidia-environments
description: "Sumit's NVIDIA machine types and the Omnistation package/egress policy"
metadata: 
  node_type: memory
  type: reference
  originSessionId: 16fc523d-f1cf-4090-81b7-80b261e20d7f
---

Sumit works across three environment types; detect and adapt:

1. **macOS** — primary workstation, Homebrew, full internet.
2. **NVIDIA Linux VM** — internal + external internet; can git-sync to personal GitHub AND NVIDIA GitLab (`gitlab-master.nvidia.com`, allowlisted).
3. **NVIDIA Omnistation sandbox** — locked down, NO open internet (egress ACL allowlist). Detect via hostname `omni-*` and/or `SSH_SESSION_WEBPROXY_ADDR` (Teleport). `github.com`=503, `api.github.com`=403, but `raw.githubusercontent.com`/`objects.githubusercontent.com` work. No personal-git access (can't push to personal GitHub from here).

**Omnistation install policy (strict order; NEVER proxy/tunnel around the ACL — it's monitored and prohibited):**
1. `sudo apt install -y <pkg>` (internal mirror, allowlisted; has eza, fzf, ripgrep, jq, gh, zsh-autosuggestions, zsh-syntax-highlighting, etc.).
2. Language managers via NVIDIA Artifactory: pip index `https://urm.nvidia.com/artifactory/api/pypi/nv-shared-pypi/simple` (new host `artifactory.nvidia.com`), npm registry `https://urm.nvidia.com/artifactory/api/npm/npm/`, `cargo install <crate>`.
3. `artifactory-download <url> <out>` for raw binaries.
4. If only on a non-NVIDIA GitHub org: STOP and ask the human (tsh scp from laptop / mirror to NVIDIA GitLab / file an ACL exception).

Migration note: NVIDIA is moving urm.nvidia.com → artifactory.nvidia.com (URM retires ~May 2026; new host needs auth — join DL `it-aws-artifactory-users`, generate an Identity Token, use username+token). Used by the dotfiles installer ([[dotfiles-repo]]).
