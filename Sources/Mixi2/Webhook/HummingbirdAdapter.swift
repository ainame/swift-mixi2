#if HummingbirdWebhookAdapter
import Foundation
import HTTPTypes
import Hummingbird

/// A ``WebhookServerAdapter`` backed by the Hummingbird HTTP server framework.
///
/// Exposes two routes:
/// - `GET  /healthz` — returns `"OK"` (for liveness probes).
/// - `POST /events` — verifies the signature, parses events, and dispatches them.
///
/// Enable the `HummingbirdWebhookAdapter` package trait to use this type.
@available(macOS 15.0, iOS 18.0, *)
public struct HummingbirdAdapter: WebhookServerAdapter {
    private let hostname: String
    private let port: Int

    public init(hostname: String = "0.0.0.0", port: Int = 8080) {
        self.hostname = hostname
        self.port = port
    }

    public func run(
        webhookHandler: WebhookHandler,
        eventHandler: @Sendable @escaping (Event) async throws -> Void
    ) async throws {
        let signatureField = HTTPField.Name("x-mixi2-application-event-signature")!
        let timestampField = HTTPField.Name("x-mixi2-application-event-timestamp")!

        let router = Router()
        router.get("/healthz") { _, _ in "OK" }
        router.post("/events") { request, _ -> Response in
            let signature = request.headers[values: signatureField].first ?? ""
            let timestamp = request.headers[values: timestampField].first ?? ""
            let bodyBuffer = try await request.body.collect(upTo: 4 * 1024 * 1024)
            let body = Data(bodyBuffer.readableBytesView)

            let events: [Event]
            do {
                events = try webhookHandler.handle(body: body, signature: signature, timestamp: timestamp)
            } catch let error as WebhookError {
                throw HTTPError(.badRequest, message: "\(error)")
            }

            for event in events {
                try await eventHandler(event)
            }
            return Response(status: .noContent)
        }

        let app = Application(
            router: router,
            configuration: .init(address: .hostname(hostname, port: port))
        )
        try await app.runService()
    }
}
#endif
