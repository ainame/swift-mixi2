# Changelog

All notable changes to this project will be documented in this file.

## 0.0.2 - 2026-03-29

### Added

- Added support for the `DeletePost` unary RPC via `mixi2.apiClient.deletePost(_:)`.

### Changed

- Updated vendored `mixi2-api` to `v1.1.0`.
- Regenerated gRPC/protobuf Swift sources for the `mixi2-api` `v1.1.0` schema.
- Improved Linux support documentation and Docker build workflow for package consumers.

## 0.0.1 - 2026-03-28

### Added

- Initial public release of `swift-mixi2`.
- Shipped generated gRPC client bindings, authentication support, event streaming, and webhook handling.
