# syntax=docker/dockerfile:1

# ── Build stage ───────────────────────────────────────────────────────────────
FROM swift:6.2.4 AS builder

# Use a path ending in "swift-mixi2" so the directory name matches the
# package identifier used in Demo sub-package manifests (package: "swift-mixi2").
WORKDIR /workspace/swift-mixi2

# Copy the entire repository so Demo/DockerApp can resolve its local dependency.
COPY . .

WORKDIR /workspace/swift-mixi2/Demo/DockerApp

# Build a release binary with the Swift stdlib statically linked so the
# runtime image does not need a full Swift installation.
RUN swift build -c release --product DockerApp --static-swift-stdlib

# ── Runtime stage ─────────────────────────────────────────────────────────────
FROM ubuntu:22.04

# BoringSSL (via swift-nio-ssl) and gRPC TLS need libssl and CA certificates.
RUN apt-get update \
    && apt-get install -y --no-install-recommends libssl3 ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /workspace/swift-mixi2/Demo/DockerApp/.build/release/DockerApp /usr/local/bin/docker-app

# Run as non-root for least-privilege deployments.
RUN useradd --system --no-create-home appuser
USER appuser

# Environment variables — supply real values at runtime via -e or a secret store.
# ENV MIXI2_API_HOST=
# ENV MIXI2_STREAM_HOST=
# ENV MIXI2_CLIENT_ID=
# ENV MIXI2_CLIENT_SECRET=
# ENV MIXI2_TOKEN_URL=
# ENV MIXI2_AUTH_KEY=

ENTRYPOINT ["/usr/local/bin/docker-app"]
