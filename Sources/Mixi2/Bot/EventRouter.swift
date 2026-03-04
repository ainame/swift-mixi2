import Synchronization

/// Routes incoming mixi2 events to typed handlers.
///
/// Register handlers with ``on(_:handler:)`` by passing any type that conforms
/// to ``Mixi2EventMessage``. Multiple handlers for the same or different types
/// can be registered — all matching handlers are called in registration order.
///
/// ```swift
/// let router = EventRouter()
/// router.on(PostCreatedEvent.self) { event in
///     print("new post:", event.post.content)
/// }
/// router.on(ChatMessageReceivedEvent.self) { event in
///     print("chat:", event.message.content)
/// }
/// ```
///
/// To support a new event type without modifying `EventRouter`, simply conform it to
/// ``Mixi2EventMessage`` and pass it to ``on(_:handler:)``.
@available(macOS 15.0, iOS 18.0, *)
public final class EventRouter: Sendable {
    private typealias EventHandler = @Sendable (Mixi2Event) async throws -> Void

    private let handlers: Mutex<[EventHandler]> = .init([])

    public init() {}

    /// Registers a handler for events whose message type matches `T`.
    ///
    /// The handler is invoked only when an incoming event can be extracted as `T`;
    /// all other events are silently skipped.
    public func on<T: Mixi2EventMessage>(
        _: T.Type,
        handler: @Sendable @escaping (T) async throws -> Void
    ) {
        handlers.withLock {
            $0.append { event in
                guard let message = T.extract(from: event) else { return }
                try await handler(message)
            }
        }
    }

    /// Dispatches a single event to all registered handlers whose type matches.
    func handle(_ event: Mixi2Event) async throws {
        let snapshot = handlers.withLock { $0 }
        for handler in snapshot {
            try await handler(event)
        }
    }
}
