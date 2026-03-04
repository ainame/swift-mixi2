# swift-mixi2

A Swift gRPC client library for the [mixi2](https://mixi2.com) Application API. Provides authentication, event streaming, and webhook verification on top of generated protobuf stubs.

## Requirements

- Swift 6.0+
- macOS 15+, iOS 18+, or Linux

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

### Creating a client

```swift
import Mixi2

let authenticator = ClientCredentialsAuthenticator(
    clientID: "your-client-id",
    clientSecret: "your-client-secret",
    tokenURL: URL(string: "https://auth.mixi2.com/oauth/token")!
)

let config = Mixi2Client.Configuration(
    host: "api.mixi2.com",
    authenticator: authenticator,
    authKey: "your-auth-key"   // optional
)

let client = try Mixi2Client(configuration: config)
```

Or load configuration from environment variables (`MIXI2_API_HOST`, `MIXI2_CLIENT_ID`, `MIXI2_CLIENT_SECRET`, `MIXI2_TOKEN_URL`, and optionally `MIXI2_AUTH_KEY`, `MIXI2_API_PORT`):

```swift
let config = try await Mixi2Client.Configuration.fromEnvironment()
let client = try Mixi2Client(configuration: config)
```

The gRPC connection is built on [grpc-swift](https://github.com/grpc/grpc-swift) v2 with a SwiftNIO HTTP/2 transport (`HTTP2ClientTransport.Posix`). Network I/O does not go through `URLSession` — the only use of `URLSession` is the OAuth2 token fetch inside `ClientCredentialsAuthenticator`.

The client's underlying gRPC transport must be running in a concurrent task:

```swift
try await withThrowingDiscardingTaskGroup { group in
    group.addTask { try await client.run() }

    // Make API calls here
    let response = try await client.apiClient.getUsers(.with {
        $0.userIDList = ["user-123"]
    })
    print(response.users)

    client.shutdown()
}
```

### Available API methods

`client.apiClient` exposes all unary RPCs from the ApplicationService:

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

### Event streaming

Subscribe to real-time events using `EventStream`, which wraps the server-streaming `SubscribeEvents` RPC as an `AsyncSequence`. PING events are filtered automatically and the stream reconnects on failure with exponential backoff (1 s / 2 s / 4 s, up to 3 retries).

```swift
let stream = EventStream(client: client.streamClient)

for try await event in stream {
    switch event.eventType {
    case .postCreated:
        let post = event.postCreatedEvent.post
        print("New post: \(post.text)")
    case .chatMessageReceived:
        let message = event.chatMessageReceivedEvent.message
        print("New message: \(message.text)")
    default:
        break
    }
}
```

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

### Custom authentication

Conform to the `Authenticator` protocol to supply tokens from any source:

```swift
struct MyAuthenticator: Authenticator {
    func accessToken() async throws -> String {
        // fetch or return a cached token
    }
}
```

## Using generated stubs directly

The `Mixi2GRPC` product exposes the raw generated Swift types for all proto messages and services, so you can use them independently of the `Mixi2` SDK:

```swift
import Mixi2GRPC

let request = Social_Mixi_Application_Service_ApplicationApi_V1_GetPostsRequest.with {
    $0.postIDList = ["post-abc"]
}
```

## License

MIT
