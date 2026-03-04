/// A high-level facade for building a mixi2 bot.
///
/// `Bot` owns a ``Mixi2Client``, connects to the event stream, and dispatches
/// each incoming event to the registered ``Router`` handlers.
///
/// ```swift
/// let router = Router()
///     .onPostCreated { event in
///         print("new post:", event.post.content)
///     }
///
/// let bot = try Bot(configuration: .fromEnvironment(), router: router)
/// try await bot.run()
/// ```
@available(macOS 15.0, iOS 18.0, *)
public final class Bot: Sendable {
    private let client: Mixi2Client
    private let router: Router

    public init(configuration: Mixi2Client.Configuration, router: Router) throws {
        self.client = try Mixi2Client(configuration: configuration)
        self.router = router
    }

    /// Connects to the mixi2 event stream and runs the router until the stream ends or an error is thrown.
    ///
    /// This method blocks until all work is complete. The underlying gRPC connections are shut down
    /// automatically when the event stream finishes.
    public func run() async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask { try await self.client.run() }
            group.addTask {
                defer { self.client.shutdown() }
                let stream = EventStream(client: self.client.streamClient)
                for try await event in stream {
                    try await self.router.handle(event)
                }
            }
            try await group.waitForAll()
        }
    }
}
