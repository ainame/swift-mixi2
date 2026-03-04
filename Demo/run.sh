#!/bin/sh
set -e

# ── Required ──────────────────────────────────────────────────────────────────
export MIXI2_API_HOST=""
export MIXI2_CLIENT_ID=""
export MIXI2_CLIENT_SECRET=""
export MIXI2_TOKEN_URL=""

# ── Optional ──────────────────────────────────────────────────────────────────
# export MIXI2_API_PORT="443"
# export MIXI2_AUTH_KEY=""

# ── Validate ──────────────────────────────────────────────────────────────────
for var in MIXI2_API_HOST MIXI2_CLIENT_ID MIXI2_CLIENT_SECRET MIXI2_TOKEN_URL; do
  eval "val=\$$var"
  if [ -z "$val" ]; then
    echo "Error: $var is not set" >&2
    exit 1
  fi
done

cd "$(dirname "$0")"
swift run
