/// A high-level facade for building a mixi2 bot.
///
/// `Bot` owns a ``Mixi2``, connects to the event stream, and dispatches
/// each incoming event to the registered ``EventRouter`` handlers.
///
/// ```swift
/// let router = EventRouter()
/// router.on(PostCreatedEvent.self) { context, event in
///     print("new post:", event.post.content)
/// }
///
/// let bot = try Bot(configuration: config, router: router)
/// try await bot.run()
/// ```
@available(macOS 15.0, iOS 18.0, *)
public final class Bot: Sendable {
    /// Context passed to every event handler. Provides access to the API client
    /// for making calls (e.g. sending a reply) from within a handler.
    public struct Context: Sendable {
        /// Client for making unary API calls from within an event handler.
        public let apiClient: Mixi2.APIClient
    }

    private let client: Mixi2
    private let router: EventRouter

    public init(configuration: Mixi2.Configuration, router: EventRouter) throws {
        self.client = try Mixi2(configuration: configuration)
        self.router = router
    }

    /// Connects to the mixi2 event stream and runs the router until the stream ends or an error is thrown.
    ///
    /// This method blocks until all work is complete. The underlying gRPC connections are shut down
    /// automatically when the event stream finishes.
    public func run() async throws {
        let context = Context(apiClient: client.apiClient)
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask { try await self.client.run() }
            group.addTask {
                defer { self.client.shutdown() }
                try await EventStream(client: self.client.streamClient).run { event in
                    try await self.router.handle(context, event)
                }
            }
            try await group.waitForAll()
        }
    }
}
