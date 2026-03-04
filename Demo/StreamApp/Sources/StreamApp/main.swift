import Mixi2

let configuration = try Mixi2Client.Configuration.fromEnvironment()
let router = EventRouter()

router.on(ChatMessageReceivedEvent.self) { context, event in
    print("[chat] from=\(event.issuer.userID)  room=\(event.message.roomID)  \(event.message.text)")
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

print("Connected to api=\(configuration.apiHost) stream=\(configuration.streamHost) port=\(configuration.port)")
print("Listening for events (Ctrl-C to stop)…")

let bot = try Bot(configuration: configuration, router: router)
try await bot.run()
