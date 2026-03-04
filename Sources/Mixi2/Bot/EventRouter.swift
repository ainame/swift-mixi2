import Mixi2GRPC
import Synchronization

/// Routes incoming mixi2 events to typed handlers.
///
/// Register handlers with ``on(_:handler:)`` by passing any type that conforms
/// to ``Mixi2EventMessage``. Multiple handlers for the same or different types
/// can be registered — all matching handlers are called in registration order.
///
/// Each handler receives a ``Bot/Context`` giving access to the API client,
/// and the strongly-typed event message.
///
/// ```swift
/// let router = EventRouter()
/// router.on(PostCreatedEvent.self) { context, event in
///     print("new post:", event.post.content)
/// }
/// router.on(ChatMessageReceivedEvent.self) { context, event in
///     var reply = SendChatMessageRequest()
///     reply.roomID = event.message.roomID
///     reply.text = event.message.text
///     _ = try await context.applicationService.sendChatMessage(reply)
/// }
/// ```
///
/// To support a new event type without modifying `EventRouter`, simply conform it to
/// ``Mixi2EventMessage`` and pass it to ``on(_:handler:)``.
@available(macOS 15.0, iOS 18.0, *)
public final class EventRouter: Sendable {
    private typealias EventHandler = @Sendable (Bot.Context, Event) async throws -> Void

    private let handlers: Mutex<[EventHandler]> = .init([])

    public init() {}

    /// Registers a handler for events whose message type matches `T`.
    ///
    /// The handler is invoked only when an incoming event can be extracted as `T`;
    /// all other events are silently skipped.
    public func on<T: Mixi2EventMessage>(
        _: T.Type,
        handler: @Sendable @escaping (Bot.Context, T) async throws -> Void
    ) {
        handlers.withLock {
            $0.append { context, event in
                guard let message = T.extract(from: event) else { return }
                try await handler(context, message)
            }
        }
    }

    /// Dispatches a single event to all registered handlers whose type matches.
    func handle(_ context: Bot.Context, _ event: Event) async throws {
        let snapshot = handlers.withLock { $0 }
        for handler in snapshot {
            try await handler(context, event)
        }
    }
}
