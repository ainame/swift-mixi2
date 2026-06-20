# Changelog

All notable changes to this project will be documented in this file.

## 1.2.0 - 2026-06-20

### Added

- Added generated client support for the `GetCommunities`, `GetCommunityTimeline`, `GetCommunityMemberList`, `RestrictCommunityPost`, `GetCommunitiesUsingApplication`, and `SendDirectMessageToCommunityMember` unary RPCs. [#2](https://github.com/ainame/swift-mixi2/pull/2)
- Added generated event message extraction for `CommunityMemberChangedEvent` and `CommunityPluginManagedEvent`. [#2](https://github.com/ainame/swift-mixi2/pull/2)

### Changed

- Aligned the package release version with the upstream `mixi2-api` release starting at `1.2.0`. [#2](https://github.com/ainame/swift-mixi2/pull/2)
- Updated vendored `mixi2-api` to `v1.2.0`. [#2](https://github.com/ainame/swift-mixi2/pull/2)
- Regenerated gRPC/protobuf Swift sources for the `mixi2-api` `v1.2.0` schema. [#2](https://github.com/ainame/swift-mixi2/pull/2)

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
