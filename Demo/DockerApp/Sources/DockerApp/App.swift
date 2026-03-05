import Configuration
import Foundation
import Logging
import Mixi2
import ServiceLifecycle

@main
struct DockerApp {
    static func main() async throws {
        let config = ConfigReader(providers: [EnvironmentVariablesProvider()])

        let configuration = try Mixi2.Configuration(
            apiHost: config.requiredString(forKey: "mixi2.api.host"),
            streamHost: config.requiredString(forKey: "mixi2.stream.host"),
            port: config.int(forKey: "mixi2.api.port", default: 443),
            authenticator: ClientCredentialsAuthenticator(
                clientID: config.requiredString(forKey: "mixi2.client.id"),
                clientSecret: config.requiredString(forKey: "mixi2.client.secret", isSecret: true),
                tokenURL: config.requiredString(forKey: "mixi2.token.url", as: URL.self),
            ),
            authKey: config.string(forKey: "mixi2.auth.key", isSecret: true),
        )

        let router = EventRouter()

        router.on(ChatMessageReceivedEvent.self) { context, event in
            print(
                "[chat] from=\(event.issuer.userID)  room=\(event.message.roomID)  \(event.message.text)"
            )
            guard !event.message.text.isEmpty else { return }
            var reply = SendChatMessageRequest()
            reply.roomID = event.message.roomID
            reply.text = event.message.text
            _ = try await context.apiClient.sendChatMessage(reply)
        }

        router.on(PostCreatedEvent.self) { _, event in
            print("[post] from=\(event.issuer.userID)  \(event.post.text)")
        }

        let bot = try Bot(configuration: configuration, router: router)
        let serviceGroup = ServiceGroup(services: [bot], logger: Logger(label: "DockerApp"))
        try await serviceGroup.run()
    }
}
