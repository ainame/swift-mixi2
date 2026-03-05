import Configuration
import Foundation
import Mixi2

@main
struct WebHookApp {
    static func main() async throws {
        // MARK: - Configuration

        let dotEnvProvider = try await EnvironmentVariablesProvider(environmentFilePath: ".env", allowMissing: true)
        let config = ConfigReader(providers: [EnvironmentVariablesProvider(), dotEnvProvider])

        let publicKeyBase64 = try config.requiredString(forKey: "mixi2.public.key", isSecret: true)
        guard let keyData = Data(base64Encoded: publicKeyBase64) else {
            fputs("Error: MIXI2_PUBLIC_KEY is not a valid base64-encoded Ed25519 public key\n", stderr)
            exit(1)
        }

        let apiHost = try config.requiredString(forKey: "mixi2.api.host")
        let webhookPort = config.int(forKey: "mixi2.webhook.port", default: 8080)

        let configuration = try Mixi2.Configuration(
            apiHost: apiHost,
            streamHost: apiHost,
            port: config.int(forKey: "mixi2.api.port", default: 443),
            authenticator: ClientCredentialsAuthenticator(
                clientID: config.requiredString(forKey: "mixi2.client.id"),
                clientSecret: config.requiredString(forKey: "mixi2.client.secret", isSecret: true),
                tokenURL: config.requiredString(forKey: "mixi2.token.url", as: URL.self),
            ),
            authKey: config.string(forKey: "mixi2.auth.key", isSecret: true),
            webhookPublicKey: keyData,
        )

        // MARK: - Event Handlers

        let eventRouter = EventRouter()

        eventRouter.on(ChatMessageReceivedEvent.self) { context, msg in
            print("[chat] from=\(msg.issuer.userID)  room=\(msg.message.roomID)  \(msg.message.text)")
            guard !msg.message.text.isEmpty else {
                print("[chat] skipping echo — no text (image-only message)")
                return
            }
            var reply = SendChatMessageRequest()
            reply.roomID = msg.message.roomID
            reply.text = msg.message.text
            _ = try await context.apiClient.sendChatMessage(reply)
        }

        eventRouter.on(PostCreatedEvent.self) { _, post in
            print("[post] from=\(post.issuer.userID)  \(post.post.text)")
        }

        // MARK: - Run

        let bot = try Bot(
            configuration: configuration,
            router: eventRouter,
            mode: .webhook(HummingbirdAdapter(port: webhookPort)),
        )
        print("Listening on port \(webhookPort) (Ctrl-C to stop)…")
        try await bot.run()
    }
}
