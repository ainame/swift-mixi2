import Foundation
import HTTPTypes
import Hummingbird
import Mixi2
import Mixi2GRPC

// MARK: - Configuration

guard let publicKeyHex = ProcessInfo.processInfo.environment["MIXI2_PUBLIC_KEY"] else {
    fputs("Error: MIXI2_PUBLIC_KEY is not set\n", stderr)
    exit(1)
}
guard let publicKeyBytes = Data(hexEncoded: publicKeyHex) else {
    fputs("Error: MIXI2_PUBLIC_KEY is not valid hex\n", stderr)
    exit(1)
}

let clientConfiguration = try Mixi2Client.Configuration.fromEnvironment()
let webhookHandler = try WebhookHandler(publicKeyBytes: publicKeyBytes)
let mixi2Client = try Mixi2Client(configuration: clientConfiguration)

let port = Int(ProcessInfo.processInfo.environment["MIXI2_WEBHOOK_PORT"] ?? "8080") ?? 8080

// MARK: - Routes

let router = Router()

router.get("/healthz") { _, _ in "OK" }

router.post("/events") { request, _ -> Response in
    let signatureField = HTTPField.Name("x-mixi2-application-event-signature")!
    let timestampField = HTTPField.Name("x-mixi2-application-event-timestamp")!
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
        if let msg = ChatMessageReceivedEvent.extract(from: event) {
            print("[chat] from=\(msg.issuer.userID)  room=\(msg.message.roomID)  \(msg.message.text)")
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
    configuration: .init(address: .hostname("0.0.0.0", port: port))
)

print("Listening on port \(port) (Ctrl-C to stop)…")

try await withThrowingTaskGroup(of: Void.self) { group in
    group.addTask { try await mixi2Client.run() }
    group.addTask {
        defer { mixi2Client.shutdown() }
        try await app.runService()
    }
    try await group.waitForAll()
}

// MARK: - Helpers

extension Data {
    init?(hexEncoded hex: String) {
        guard hex.count.isMultiple(of: 2) else { return nil }
        var data = Data(capacity: hex.count / 2)
        var index = hex.startIndex
        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2)
            guard let byte = UInt8(hex[index..<next], radix: 16) else { return nil }
            data.append(byte)
            index = next
        }
        self = data
    }
}
