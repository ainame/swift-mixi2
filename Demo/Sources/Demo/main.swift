import Mixi2
import Mixi2GRPC

let configuration = try Mixi2Client.Configuration.fromEnvironment()

let router = EventRouter()

router.on(ChatMessageReceivedEvent.self) { event in
    print("[chat] from=\(event.issuer.userID)  room=\(event.message.roomID)  \(event.message.text)")
}

router.on(PostCreatedEvent.self) { event in
    print("[post] from=\(event.issuer.userID)  \(event.post.text)")
}

print("Connected to api=\(configuration.apiHost) stream=\(configuration.streamHost) port=\(configuration.port)")
print("Listening for events (Ctrl-C to stop)…")

let bot = try Bot(configuration: configuration, router: router)
try await bot.run()
