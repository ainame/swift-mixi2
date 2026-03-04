import Configuration
import Foundation
import Mixi2

@main
struct StreamApp {
    static func main() async throws {
        let dotEnvProvider = try await EnvironmentVariablesProvider(
            environmentFilePath: ".env", allowMissing: true)
        let config = ConfigReader(providers: [EnvironmentVariablesProvider(), dotEnvProvider])

        guard let apiHost = config.string(forKey: "mixi2.api.host") else {
            fputs("Error: MIXI2_API_HOST is not set\n", stderr)
            exit(1)
        }
        guard let streamHost = config.string(forKey: "mixi2.stream.host") else {
            fputs("Error: MIXI2_STREAM_HOST is not set\n", stderr)
            exit(1)
        }
        guard let clientID = config.string(forKey: "mixi2.client.id") else {
            fputs("Error: MIXI2_CLIENT_ID is not set\n", stderr)
            exit(1)
        }
        guard let clientSecret = config.string(forKey: "mixi2.client.secret") else {
            fputs("Error: MIXI2_CLIENT_SECRET is not set\n", stderr)
            exit(1)
        }
        guard let tokenURL = config.string(forKey: "mixi2.token.url", as: URL.self) else {
            fputs("Error: MIXI2_TOKEN_URL is not set\n", stderr)
            exit(1)
        }
        let port = config.int(forKey: "mixi2.api.port", default: 443)
        let authKey = config.string(forKey: "mixi2.auth.key")

        let authenticator = ClientCredentialsAuthenticator(
            clientID: clientID, clientSecret: clientSecret, tokenURL: tokenURL)
        let configuration = Mixi2Client.Configuration(
            apiHost: apiHost, streamHost: streamHost, port: port,
            authenticator: authenticator, authKey: authKey)

        let router = EventRouter()

        router.on(ChatMessageReceivedEvent.self) { context, event in
            print(
                "[chat] from=\(event.issuer.userID)  room=\(event.message.roomID)  \(event.message.text)"
            )
            guard !event.message.text.isEmpty else {
                print("[chat] skipping echo — no text (image-only message)")
                return
            }
            var reply = SendChatMessageRequest()
            reply.roomID = event.message.roomID
            reply.text = event.message.text
            _ = try await context.applicationService.sendChatMessage(reply)
        }

        router.on(PostCreatedEvent.self) { _, event in
            print("[post] from=\(event.issuer.userID)  \(event.post.text)")
        }

        print(
            "Connected to api=\(configuration.apiHost) stream=\(configuration.streamHost) port=\(configuration.port)"
        )
        print("Listening for events (Ctrl-C to stop)…")

        let bot = try Bot(configuration: configuration, router: router)
        try await bot.run()
    }
}
