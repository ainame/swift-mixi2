import Mixi2GRPC

/// A protocol for protobuf message types that can be extracted from a raw ``Event``.
///
/// Conform an event message type to this protocol to use it with
/// ``Router/on(_:handler:)``. No changes to `Router` are needed when
/// new event types are added — add a conformance in the proto and run ``make generate``.
@available(macOS 15.0, iOS 18.0, *)
public protocol Mixi2EventMessage: Sendable {
    /// Extracts this message from a raw event, or returns `nil` for a different type.
    static func extract(from event: Event) -> Self?
}
