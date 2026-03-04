import Configuration
import Mixi2
import Mixi2GRPC

// Build a ConfigReader from the process environment.
// You can add more providers (e.g. FileProvider<JSONSnapshot>, InMemoryProvider)
// before EnvironmentVariablesProvider to supply defaults or layered overrides.
//
// Keys → env vars (swift-configuration's default mapping):
//   mixi2.api.host      → MIXI2_API_HOST
//   mixi2.client.id     → MIXI2_CLIENT_ID
//   mixi2.client.secret → MIXI2_CLIENT_SECRET
//   mixi2.token.url     → MIXI2_TOKEN_URL
//   mixi2.api.port      → MIXI2_API_PORT  (optional, default 443)
//   mixi2.auth.key      → MIXI2_AUTH_KEY  (optional)
let config = ConfigReader(provider: EnvironmentVariablesProvider())

let configuration = try Mixi2Client.Configuration.fromEnvironment(using: config)
let client = try Mixi2Client(configuration: configuration)

// Run the gRPC transport in a background task.
let runTask = Task {
    try await client.run()
}

print("Connected to api=\(configuration.apiHost) stream=\(configuration.streamHost) port=\(configuration.port)")
print("Listening for events (Ctrl-C to stop)…")

let events = EventStream(client: client.streamClient)

do {
    for try await event in events {
        switch event.body {
        case .chatMessageReceivedEvent(let e):
            print("[chat] from=\(e.issuer.userID)  room=\(e.message.roomID)  \(e.message.text)")
            guard !e.message.text.isEmpty else {
                print("[chat] skipping echo — no text (image-only message)")
                break
            }
            var reply = Social_Mixi_Application_Service_ApplicationApi_V1_SendChatMessageRequest()
            reply.roomID = e.message.roomID
            reply.text = e.message.text
            _ = try await client.apiClient.sendChatMessage(reply)
        case .postCreatedEvent(let e):
            print("[post] from=\(e.issuer.userID)  \(e.post.text)")
        default:
            print("[event] type=\(event.eventType)  id=\(event.eventID)")
        }
    }
} catch {
    print("Stream error: \(error)")
}

client.shutdown()
runTask.cancel()
