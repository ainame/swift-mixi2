import Configuration
import Foundation
import Mixi2

@main
struct StreamApp {
    static func main() async throws {
        let dotEnvProvider = try await EnvironmentVariablesProvider(
            environmentFilePath: ".env", allowMissing: true)
        let config = ConfigReader(providers: [EnvironmentVariablesProvider(), dotEnvProvider])

        let apiHost = try await config.fetchRequiredString(forKey: "mixi2.api.host")
        let streamHost = try await config.fetchRequiredString(forKey: "mixi2.stream.host")
        let clientID = try await config.fetchRequiredString(forKey: "mixi2.client.id")
        let clientSecret = try await config.fetchRequiredString(forKey: "mixi2.client.secret", isSecret: true)
        let tokenURL = try await config.fetchRequiredString(forKey: "mixi2.token.url", as: URL.self)
        let port = try await config.fetchInt(forKey: "mixi2.api.port", default: 443)
        let authKey = try await config.fetchString(forKey: "mixi2.auth.key", isSecret: true)

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
