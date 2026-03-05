# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
swift build              # build all targets
swift build --traits HummingbirdWebhookAdapter   # build with Hummingbird adapter enabled
swift build --target Mixi2GRPC   # build generated stubs only
swift build --target Mixi2       # build SDK only
swift test               # run all tests
swift test --filter WebhookHandlerTests   # run a specific test suite
swift test --filter "Accepts valid signature"  # run a single test by name
make generate            # regenerate Sources/Mixi2GRPC/Generated/ from proto files
make build               # alias for swift build
make test                # alias for swift test
```

## Architecture

Two SPM library products:

- **`Mixi2GRPC`** (`Sources/Mixi2GRPC/Generated/`) — committed generated code, no toolchain needed by consumers. Generated from `../../mixigroup/mixi2-api/proto` using `buf` + `protoc-gen-swift` + `protoc-gen-grpc-swift-2`. Files use `PathToUnderscores` naming (e.g. `social_mixi_application_service_application_api_v1_service.pb.swift`) to avoid SPM build system collisions from same-named files.

- **`Mixi2`** (`Sources/Mixi2/`) — handwritten SDK with four subsystems:
  - **Export** — `Sources/Mixi2/export.swift` re-exports `Mixi2GRPC` via `@_exported import Mixi2GRPC`. Consumers only need `import Mixi2`.
  - **Auth** — `Authenticator` protocol + `ClientCredentialsAuthenticator` actor (OAuth2 Client Credentials flow via `URLSession`, 60-second expiry buffer, actor-isolated token cache). `AuthClientInterceptor` is a grpc-swift v2 `ClientInterceptor` that injects `Authorization: Bearer <token>` and optional `x-auth-key` into every RPC's metadata.
  - **Client** — `Mixi2Client` wraps `HTTP2ClientTransport.Posix` + `GRPCClient` wired with the auth interceptor. Exposes `apiClient` (`ApplicationService` API — unary RPCs) and `streamClient` (`ApplicationService` Stream — server-streaming). `Configuration.fromEnvironment()` reads `MIXI2_API_HOST`, `MIXI2_CLIENT_ID`, `MIXI2_CLIENT_SECRET`, `MIXI2_TOKEN_URL`, optionally `MIXI2_AUTH_KEY` / `MIXI2_API_PORT`.
  - **Event** — `EventStream` wraps `subscribeEvents` via a `run(_:)` method backed by `withThrowingTaskGroup` (structured concurrency — producer is a child task, auto-cancelled). Filters `.ping` events. Reconnects with exponential backoff (1 s / 2 s / 4 s, max 3 retries) via `withReconnect`. Type is named `EventStream` and method `run` — intentionally Swift-idiomatic, not `EventWatcher`/`watch`.
  - **Bot** — Conforms to `ServiceLifecycle.Service`. `mode:` (`RunMode`) set at init (default `.stream`, or `.webhook(adapter)`); `run()` dispatches accordingly. Wrap in `ServiceGroup` for production signal handling. `withGracefulShutdownHandler` inside `run()` is the correct Service pattern — ServiceGroup sets the task-local, Bot responds.
  - **EventRouter** — dispatches events via generic `on<T: Mixi2EventMessage>(_:handler:)`. Handlers stored in `Mutex<[EventHandler]>` from `Synchronization`.
  - **EventMessage** — `Mixi2EventMessage` protocol (`Sources/Mixi2/Bot/EventMessage.swift`). Conformances in `Sources/Mixi2/Generated/EventMessageExtensions.swift` — generated, do not edit by hand.
  - **Webhook** — `WebhookHandler` verifies Ed25519 signatures (swift-crypto `Curve25519.Signing`) over `body + timestamp`, validates ±300 s timestamp window. `WebhookServerAdapter` protocol for HTTP framework integration. `HummingbirdAdapter` (gated by `HummingbirdWebhookAdapter` trait, `#if HummingbirdWebhookAdapter`) uses `app.run()` not `app.runService()` — avoids nested ServiceGroup with competing SIGTERM handlers.

## Demo apps

Two standalone SPM executables under `Demo/`, each with its own `Package.swift` referencing the root package via `path: "../../"`:

- **`Demo/StreamApp/`** — gRPC event stream bot (echo chat, print posts). Run via `Demo/StreamApp/run.sh`.
- **`Demo/WebHookApp/`** — Hummingbird HTTP server receiving webhook events (`POST /events`, `GET /healthz`). Run via `Demo/WebHookApp/run.sh`. Requires `MIXI2_PUBLIC_KEY` as a **base64-encoded** Ed25519 public key.

Both use `@main` struct with `static func main() async throws`. Entry file is `App.swift` — `@main` is incompatible with `main.swift` (Swift reserves that filename for top-level code).

`Demo/.gitignore` excludes `.build/` — never commit build artifacts from Demo apps.

## grpc-swift v2 API notes

This library uses **grpc-swift v2** (not v1). Key differences from v1:
- `GRPCClient(transport:interceptors:)` — interceptors are `[any ClientInterceptor]`
- `ClientInterceptor.intercept(request:context:next:)` — `next` is **not** `@Sendable`
- `Metadata` string values: set with `replaceOrAddString(_:forKey:)`, read with `metadata[stringValues: "key"]`
- Client lifecycle: `runConnections()` to start (blocks), `beginGracefulShutdown()` to stop
- Server-streaming response is handled via closure: `client.subscribeEvents(message) { response in ... }`; iterate messages with `for try await msg in response.messages`

## Code generation

Prerequisites (install via brew): `buf`, `swift-protobuf` (provides `protoc-gen-swift`), `protoc-gen-grpc-swift` (provides `protoc-gen-grpc-swift-2`).

Proto source lives at `../../mixigroup/mixi2-api/proto` relative to this repo (i.e. `github.com/mixigroup/mixi2-api`).

`make generate` clears `Sources/Mixi2GRPC/Generated/`, re-runs `buf generate`, then runs `ruby scripts/generate_event_message_extensions.rb` to regenerate `Sources/Mixi2/Generated/EventMessageExtensions.swift`.

## Concurrency

Built with swift-tools-version 6.2. Follow structured concurrency practices and modern concurrency APIs (`withThrowingTaskGroup`, `Mutex`, `@concurrent`) throughout.

## SPM Traits

`Package.swift` parameter order (compiler-enforced): `name` → `platforms` → `products` → `traits` → `dependencies` → `targets`. Traits require swift-tools-version 6.2 in every `Package.swift` that enables them (including Demo apps). SPM trait names map directly to `#if TraitName` conditional compilation flags.
