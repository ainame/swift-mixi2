import Foundation
import ServiceLifecycle

/// A high-level facade for building a mixi2 bot.
///
/// `Bot` owns a ``Mixi2``, connects to the event stream or receives webhook events,
/// and dispatches each incoming event to the registered ``EventRouter`` handlers.
///
/// **Stream mode** (default):
/// ```swift
/// let router = EventRouter()
/// router.on(PostCreatedEvent.self) { context, event in
///     print("new post:", event.post.content)
/// }
///
/// let bot = try Bot(configuration: config, router: router)
/// try await bot.run()
/// ```
///
/// **Webhook mode** (requires `HummingbirdWebhookAdapter` trait or a custom adapter):
/// ```swift
/// let bot = try Bot(configuration: config, router: router)
/// try await bot.run(with: .webhook(HummingbirdAdapter(port: 8080)))
/// ```
@available(macOS 15.0, iOS 18.0, *)
public final class Bot: Sendable, Service {
    /// Selects the transport mode for receiving events.
    public enum RunMode: Sendable {
        /// Receive events via gRPC server-streaming (default).
        case stream
        /// Receive events via HTTP webhook using the given adapter.
        case webhook(any WebhookServerAdapter)
    }

    /// Context passed to every event handler. Provides access to the API client
    /// for making calls (e.g. sending a reply) from within a handler.
    public struct Context: Sendable {
        /// Client for making unary API calls from within an event handler.
        public let apiClient: Mixi2.APIClient
    }

    private let client: Mixi2
    private let router: EventRouter
    private let webhookPublicKey: Data?

    public init(configuration: Mixi2.Configuration, router: EventRouter) throws {
        client = try Mixi2(configuration: configuration)
        self.router = router
        webhookPublicKey = configuration.webhookPublicKey
    }

    /// Connects to the mixi2 event stream and runs the router until the stream ends or an error is thrown.
    ///
    /// Equivalent to `run(with: .stream)`. Conforms to `ServiceLifecycle.Service`.
    public func run() async throws {
        try await run(with: .stream)
    }

    /// Runs the bot in the given mode until cancelled or gracefully shut down.
    public func run(with mode: RunMode) async throws {
        let context = Context(apiClient: client.apiClient)
        switch mode {
        case .stream:
            try await runStream(context: context)
        case let .webhook(adapter):
            try await runWebhook(context: context, adapter: adapter)
        }
    }

    private func runStream(context: Context) async throws {
        try await withGracefulShutdownHandler {
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
        } onGracefulShutdown: {
            self.client.shutdown()
        }
    }

    private func runWebhook(context: Context, adapter: any WebhookServerAdapter) async throws {
        guard let publicKey = webhookPublicKey else {
            preconditionFailure("webhookPublicKey must be set in Mixi2.Configuration for webhook mode")
        }
        let webhookHandler = try WebhookHandler(publicKeyBytes: publicKey)
        try await withGracefulShutdownHandler {
            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask { try await self.client.run([.api]) }
                group.addTask {
                    defer { self.client.shutdown() }
                    try await adapter.run(webhookHandler: webhookHandler) { event in
                        try await self.router.handle(context, event)
                    }
                }
                try await group.waitForAll()
            }
        } onGracefulShutdown: {
            self.client.shutdown()
        }
    }
}
