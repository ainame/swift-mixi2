import Mixi2
import Mixi2GRPC

let configuration = try Mixi2Client.Configuration.fromEnvironment()
let router = EventRouter()
let bot = try Bot(configuration: configuration, router: router)

router.on(ChatMessageReceivedEvent.self) { [bot] event in
    print("[chat] from=\(event.issuer.userID)  room=\(event.message.roomID)  \(event.message.text)")
    guard !event.message.text.isEmpty else {
        print("[chat] skipping echo — no text (image-only message)")
        return
    }
    var reply = Social_Mixi_Application_Service_ApplicationApi_V1_SendChatMessageRequest()
    reply.roomID = event.message.roomID
    reply.text = event.message.text
    _ = try await bot.apiClient.sendChatMessage(reply)
}

router.on(PostCreatedEvent.self) { event in
    print("[post] from=\(event.issuer.userID)  \(event.post.text)")
}

print("Connected to api=\(configuration.apiHost) stream=\(configuration.streamHost) port=\(configuration.port)")
print("Listening for events (Ctrl-C to stop)…")

try await bot.run()
