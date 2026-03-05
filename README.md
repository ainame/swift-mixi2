# swift-mixi2

A Swift client library for the [mixi2](https://mixi2.com) Application API (gRPC). Provides auth, gRPC streaming, and webhook support on top of generated protobuf stubs.

Official API docs: https://developer.mixi.social/docs

## Requirements

- Swift 6.2+
- macOS 15+, iOS 18+

## Installation

Add the package to your `Package.swift`:

```swift
.package(url: "https://github.com/ainame/swift-mixi2", from: "0.1.0"),
```

Then add the `Mixi2` product to your target:

```swift
.product(name: "Mixi2", package: "swift-mixi2"),
```

## Usage

### Configuration

Build a `Mixi2.Configuration` with your credentials:

```swift
let authenticator = ClientCredentialsAuthenticator(
    clientID: "your-client-id",
    clientSecret: "your-client-secret",
    tokenURL: URL(string: "https://<token-host>/oauth/token")!
)

let config = Mixi2.Configuration(
    apiHost: "<api-host>",
    streamHost: "<stream-host>",
    authenticator: authenticator,
    authKey: "your-auth-key"   // optional
)
```

### Building a bot

The simplest way to handle events is `Bot` + `EventRouter`. `Bot` manages the gRPC connections and drives the event stream; `EventRouter` routes each event to a typed handler registered with `on(_:handler:)`.

```swift
import Mixi2

let router = EventRouter()

router.on(PostCreatedEvent.self) { context, event in
    print("[post] \(event.issuer.userID): \(event.post.text)")
}

router.on(ChatMessageReceivedEvent.self) { context, event in
    print("[chat] \(event.issuer.userID): \(event.message.text)")
}

let bot = try Bot(configuration: config, router: router)
try await bot.run()
```

`bot.run()` blocks until the stream ends or an error is thrown. The gRPC connections are shut down automatically.

`on(_:handler:)` is generic over any type conforming to `Mixi2EventMessage`, so adding a handler for a new event type requires no changes to `EventRouter` — just pass the type. Multiple handlers for the same type are called in registration order.

Each handler receives a `Bot.Context` as its first argument. Use `context.apiClient` to make API calls from within a handler:

```swift
router.on(ChatMessageReceivedEvent.self) { context, event in
    var reply = SendChatMessageRequest()
    reply.roomID = event.message.roomID
    reply.text = "echo: \(event.message.text)"
    _ = try await context.apiClient.sendChatMessage(reply)
}
```

### Making API calls

For unary RPCs without event streaming, use `Mixi2` directly:

```swift
let mixi2 = try Mixi2(configuration: config)
async let running: Void = mixi2.run([.api])
defer { mixi2.shutdown() }

let response = try await mixi2.apiClient.getUsers(.with {
    $0.userIDList = ["user-123"]
})
print(response.users)

try await running
```

`mixi2.apiClient` exposes all unary RPCs from the ApplicationService:

| Method | Description |
|--------|-------------|
| `getUsers(_:)` | Fetch users by ID |
| `getPosts(_:)` | Fetch posts by ID |
| `createPost(_:)` | Create a post |
| `initiatePostMediaUpload(_:)` | Start a media upload and get an upload URL |
| `getPostMediaStatus(_:)` | Check media upload/processing status |
| `sendChatMessage(_:)` | Send a chat message to a room |
| `getStamps(_:)` | List available stamps |
| `addStampToPost(_:)` | Add a stamp to a post |

### Low-level event streaming

`EventStream` can be used directly when you don't need `Bot`:

```swift
let stream = EventStream(client: mixi2.streamClient)

try await stream.run { event in
    switch event.eventType {
    case .postCreated:
        print("New post: \(event.postCreatedEvent.post.text)")
    case .chatMessageReceived:
        print("New message: \(event.chatMessageReceivedEvent.message.text)")
    default:
        break
    }
}
```

PING events are filtered automatically. The stream reconnects on failure with exponential backoff (1 s / 2 s / 4 s, up to 3 retries).

### Webhook handling

Verify and parse incoming webhook requests from mixi2. `WebhookHandler` validates the Ed25519 signature, checks the timestamp is within ±5 minutes, and deserializes the payload.

```swift
import Mixi2

let handler = try WebhookHandler(publicKeyBytes: yourEd25519PublicKeyBytes)

// In your HTTP request handler:
let events = try handler.handle(
    body: requestBody,
    signature: request.headers["x-mixi2-application-event-signature"]!,
    timestamp: request.headers["x-mixi2-application-event-timestamp"]!
)

for event in events {
    // process event (PING events are already filtered out)
}
```

`handle(body:signature:timestamp:)` throws `WebhookError` on any verification failure:

| Error | Cause |
|-------|-------|
| `.invalidSignatureEncoding` | Signature header is not valid base64 |
| `.invalidTimestamp` | Timestamp header is not a valid integer |
| `.timestampTooOld` | Request is more than 5 minutes old |
| `.timestampInFuture` | Request timestamp is more than 5 minutes in the future |
| `.signatureInvalid` | Ed25519 signature does not match |

## License

MIT
