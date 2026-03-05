/// A framework-agnostic interface for running an HTTP server that receives mixi2 webhook events.
///
/// Implement this protocol to integrate any HTTP framework with ``Bot``.
/// The adapter is responsible for:
/// - Binding to a port and routing `POST /events` requests.
/// - Extracting the body, signature header, and timestamp header from each request.
/// - Calling ``WebhookHandler/handle(body:signature:timestamp:)`` to verify and parse the events.
/// - Invoking `eventHandler` for each verified non-ping event.
/// - Blocking until the server stops (via task cancellation or graceful shutdown).
///
/// A built-in Hummingbird-based implementation, ``HummingbirdAdapter``, is available when the
/// `HummingbirdWebhookAdapter` package trait is enabled.
@available(macOS 15.0, iOS 18.0, *)
public protocol WebhookServerAdapter: Sendable {
    func run(
        webhookHandler: WebhookHandler,
        eventHandler: @Sendable @escaping (Event) async throws -> Void,
    ) async throws
}
