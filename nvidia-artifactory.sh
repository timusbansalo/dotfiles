#!/usr/bin/env bash
# dotfiles-version: 1.0.1
# nvidia-artifactory.sh — point pip / npm (and document cargo) at NVIDIA's
# internal Artifactory virtual repos, so package installs work on machines with
# no open internet (Omnistation) without ever proxying around the egress ACL.
#
# Auto-invoked by install-linux.sh on NVIDIA environments, but also safe to run
# standalone and to re-run (idempotent). pip + npm use anonymous-read shared
# virtual repos, so no token is needed. cargo needs an identity token, so we
# only PRINT those steps (can't be automated).
#
# Policy (never violate): install order is apt -> pip/npm/cargo via Artifactory
# -> artifactory-download -> ask a human. Never configure an HTTP proxy, disable
# TLS, or tunnel around the ACL. See ~/dotfiles/CLAUDE.md.
#
# Override host with NV_ARTIFACTORY_HOST=urm.nvidia.com|artifactory.nvidia.com.

set -euo pipefail

# urm.nvidia.com = current shared host (anonymous read). artifactory.nvidia.com
# = the migration target (needs DL it-aws-artifactory-users + login). Default to
# urm while it still works; override when it retires (~May 2026).
HOST="${NV_ARTIFACTORY_HOST:-urm.nvidia.com}"
PIP_INDEX="https://${HOST}/artifactory/api/pypi/nv-shared-pypi/simple"
NPM_REGISTRY="https://${HOST}/artifactory/api/npm/npm-nv-shared/"

echo "=== NVIDIA Artifactory bootstrap (host: $HOST) ==="

# -- pip ---------------------------------------------------------------------
if command -v python3 >/dev/null 2>&1 && python3 -m pip --version >/dev/null 2>&1; then
  cur="$(python3 -m pip config get global.index-url 2>/dev/null || true)"
  if [[ "$cur" == "$PIP_INDEX" ]]; then
    echo "pip:  already pointed at nv-shared-pypi"
  else
    python3 -m pip config set global.index-url "$PIP_INDEX" >/dev/null
    echo "pip:  global.index-url -> $PIP_INDEX"
    [[ -n "$cur" ]] && echo "      (was: $cur)"
  fi
else
  echo "pip:  python3/pip not found — skipping"
fi

# -- npm ---------------------------------------------------------------------
if command -v npm >/dev/null 2>&1; then
  cur="$(npm config get registry 2>/dev/null || true)"
  if [[ "$cur" == "$NPM_REGISTRY" ]]; then
    echo "npm:  already pointed at npm-nv-shared"
  else
    npm config set registry "$NPM_REGISTRY"
    echo "npm:  registry -> $NPM_REGISTRY"
    [[ -n "$cur" ]] && echo "      (was: $cur)"
  fi
else
  echo "npm:  not found — skipping"
fi

# -- cargo (needs an identity token; print steps, don't automate) ------------
if command -v cargo >/dev/null 2>&1; then
  if [[ -f "$HOME/.cargo/config.toml" ]] && grep -q "nv-shared" "$HOME/.cargo/config.toml" 2>/dev/null; then
    echo "cargo: nv-shared registry already configured in ~/.cargo/config.toml"
  else
    cat <<'EOF'
cargo: to enable the internal registry, add to ~/.cargo/config.toml:

  [registries.nv-shared]
  index = "sparse+https://artifactory.nvidia.com/artifactory/api/cargo/nv-shared-rust-local/index/"
  credential-provider = ["cargo:token", "cargo:libsecret"]
  [net]
  git-fetch-with-cli = true

then authenticate (token from Artifactory > Edit Profile > Generate Identity Token):
  cargo login --registry nv-shared
  # paste:  Bearer <ARTIFACTORY_TOKEN>     (the "Bearer " prefix is required)

Public crates still resolve from crates.io; use --registry=nv-shared for internal.
EOF
  fi
fi

cat <<EOF

Done. Verify with:
  pip install --dry-run requests
  npm view react version
If urm.nvidia.com starts failing, re-run with:
  NV_ARTIFACTORY_HOST=artifactory.nvidia.com $0
  (new host needs DL it-aws-artifactory-users + a one-time SSO login)
EOF
