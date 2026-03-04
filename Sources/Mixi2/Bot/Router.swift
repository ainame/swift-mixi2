/// Routes incoming mixi2 events to typed handlers.
///
/// Register handlers with ``on(_:handler:)`` by passing any type that conforms
/// to ``Mixi2EventPayload``. Multiple handlers for the same or different types
/// can be registered — all matching handlers are called in registration order.
///
/// ```swift
/// let router = Router()
/// router.on(PostCreatedEvent.self) { event in
///     print("new post:", event.post.content)
/// }
/// router.on(ChatMessageReceivedEvent.self) { event in
///     print("chat:", event.message.content)
/// }
/// ```
///
/// To support a new event type without modifying `Router`, simply conform it to
/// ``Mixi2EventPayload`` and pass it to ``on(_:handler:)``.
@available(macOS 15.0, iOS 18.0, *)
public final class Router: @unchecked Sendable {
    private typealias EventHandler = @Sendable (Mixi2Event) async throws -> Void

    private var handlers: [EventHandler] = []

    public init() {}

    /// Registers a handler for events whose payload matches `T`.
    ///
    /// The handler is invoked only when an incoming event can be extracted as `T`;
    /// all other events are silently skipped.
    public func on<T: Mixi2EventMessage>(
        _: T.Type,
        handler: @Sendable @escaping (T) async throws -> Void
    ) {
        handlers.append { event in
            guard let payload = T.extract(from: event) else { return }
            try await handler(payload)
        }
    }

    /// Dispatches a single event to all registered handlers whose type matches.
    func handle(_ event: Mixi2Event) async throws {
        for handler in handlers {
            try await handler(event)
        }
    }
}
