import Configuration
import Crypto
import Foundation
import HTTPTypes
import Hummingbird
import Mixi2

let signatureField = HTTPField.Name("x-mixi2-application-event-signature")!
let timestampField = HTTPField.Name("x-mixi2-application-event-timestamp")!

@main
struct WebHookApp {
    static func main() async throws {
        // MARK: - Configuration

        let dotEnvProvider = try await EnvironmentVariablesProvider(environmentFilePath: ".env", allowMissing: true)
        let config = ConfigReader(providers: [EnvironmentVariablesProvider(), dotEnvProvider])

        guard let publicKeyBase64 = config.string(forKey: "mixi2.public.key"),
              let keyData = Data(base64Encoded: publicKeyBase64),
              let publicKey = try? Curve25519.Signing.PublicKey(rawRepresentation: keyData) else {
            fputs("Error: MIXI2_PUBLIC_KEY is not set or not a valid base64-encoded Ed25519 public key\n", stderr)
            exit(1)
        }

        guard let apiHost = config.string(forKey: "mixi2.api.host") else {
            fputs("Error: MIXI2_API_HOST is not set\n", stderr); exit(1)
        }
        guard let clientID = config.string(forKey: "mixi2.client.id") else {
            fputs("Error: MIXI2_CLIENT_ID is not set\n", stderr); exit(1)
        }
        guard let clientSecret = config.string(forKey: "mixi2.client.secret") else {
            fputs("Error: MIXI2_CLIENT_SECRET is not set\n", stderr); exit(1)
        }
        guard let tokenURL = config.string(forKey: "mixi2.token.url", as: URL.self) else {
            fputs("Error: MIXI2_TOKEN_URL is not set\n", stderr); exit(1)
        }
        let port = config.int(forKey: "mixi2.api.port", default: 443)
        let authKey = config.string(forKey: "mixi2.auth.key")
        let webhookPort = config.int(forKey: "mixi2.webhook.port", default: 8080)

        let authenticator = ClientCredentialsAuthenticator(
            clientID: clientID, clientSecret: clientSecret, tokenURL: tokenURL)
        let clientConfiguration = Mixi2Client.Configuration(
            apiHost: apiHost, streamHost: apiHost, port: port,
            authenticator: authenticator, authKey: authKey)
        let webhookHandler = WebhookHandler(publicKey: publicKey)
        let mixi2Client = try Mixi2Client(configuration: clientConfiguration)

        // MARK: - Routes

        let router = Router()

        router.get("/healthz") { _, _ in "OK" }

        router.post("/events") { request, _ -> Response in
            let signature = request.headers[values: signatureField].first ?? ""
            let timestamp = request.headers[values: timestampField].first ?? ""

            let bodyBuffer = try await request.body.collect(upTo: 4 * 1024 * 1024)
            let body = Data(bodyBuffer.readableBytesView)

            let events: [Event]
            do {
                events = try webhookHandler.handle(
                    body: body, signature: signature, timestamp: timestamp)
            } catch let error as WebhookError {
                throw HTTPError(.badRequest, message: "\(error)")
            }

            for event in events {
                if let msg = ChatMessageReceivedEvent.extract(from: event) {
                    print(
                        "[chat] from=\(msg.issuer.userID)  room=\(msg.message.roomID)  \(msg.message.text)"
                    )
                    guard !msg.message.text.isEmpty else {
                        print("[chat] skipping echo — no text (image-only message)")
                        continue
                    }
                    var reply = SendChatMessageRequest()
                    reply.roomID = msg.message.roomID
                    reply.text = msg.message.text
                    _ = try await mixi2Client.applicationService.sendChatMessage(reply)
                } else if let post = PostCreatedEvent.extract(from: event) {
                    print("[post] from=\(post.issuer.userID)  \(post.post.text)")
                }
            }

            return Response(status: .noContent)
        }

        // MARK: - Run

        let app = Application(
            router: router,
            configuration: .init(address: .hostname("0.0.0.0", port: webhookPort))
        )

        print("Listening on port \(webhookPort) (Ctrl-C to stop)…")

        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask { try await mixi2Client.run() }
            group.addTask {
                defer { mixi2Client.shutdown() }
                try await app.runService()
            }
            try await group.waitForAll()
        }
    }
}
