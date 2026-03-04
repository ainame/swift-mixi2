#!/bin/sh
set -e

# ── Required ──────────────────────────────────────────────────────────────────
export MIXI2_PUBLIC_KEY=""        # Ed25519 public key as base64 (from mixi2 developer portal)
export MIXI2_API_HOST=""
export MIXI2_TOKEN_URL=""
export MIXI2_CLIENT_ID=""
export MIXI2_CLIENT_SECRET=""

# ── Optional ──────────────────────────────────────────────────────────────────
# export MIXI2_API_PORT="443"
# export MIXI2_AUTH_KEY=""
# export MIXI2_WEBHOOK_PORT="8080"

# ── Validate ──────────────────────────────────────────────────────────────────
for var in MIXI2_PUBLIC_KEY MIXI2_API_HOST MIXI2_CLIENT_ID MIXI2_CLIENT_SECRET MIXI2_TOKEN_URL; do
  eval "val=\$$var"
  if [ -z "$val" ]; then
    echo "Error: $var is not set" >&2
    exit 1
  fi
done

cd "$(dirname "$0")"
swift run
