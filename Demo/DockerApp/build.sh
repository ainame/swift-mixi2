#!/bin/sh
# Run from anywhere — resolves the repo root and sets it as the Docker build context.
set -e
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
exec docker build -f "$REPO_ROOT/Demo/DockerApp/Dockerfile" -t mixi2-bot "$REPO_ROOT" "$@"
