import GRPCCore
import Mixi2GRPC

/// Typealias for the mixi2 event model.
public typealias Mixi2Event = Social_Mixi_Application_Model_V1_Event

/// An `AsyncSequence` of mixi2 events from a gRPC server-streaming subscription.
///
/// PING events are automatically filtered. On connection failure the stream retries
/// up to 3 times with 1s/2s/4s exponential backoff before propagating the error.
@available(macOS 15.0, iOS 18.0, *)
public struct EventStream: AsyncSequence {
    public typealias Element = Mixi2Event

    private let client: Social_Mixi_Application_Service_ApplicationStream_V1_ApplicationService.ClientProtocol

    public init(client: Social_Mixi_Application_Service_ApplicationStream_V1_ApplicationService.ClientProtocol) {
        self.client = client
    }

    public func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(client: client)
    }

    public struct AsyncIterator: AsyncIteratorProtocol {
        private let client: Social_Mixi_Application_Service_ApplicationStream_V1_ApplicationService.ClientProtocol
        private var buffer: [Mixi2Event] = []
        private var finished = false
        private var streamTask: Task<Void, Error>?
        private var continuation: AsyncThrowingStream<Mixi2Event, Error>.Continuation?
        private var inner: AsyncThrowingStream<Mixi2Event, Error>.AsyncIterator?

        init(client: Social_Mixi_Application_Service_ApplicationStream_V1_ApplicationService.ClientProtocol) {
            self.client = client
        }

        public mutating func next() async throws -> Mixi2Event? {
            if inner == nil {
                let (stream, continuation) = AsyncThrowingStream<Mixi2Event, Error>.makeStream()
                self.continuation = continuation
                self.inner = stream.makeAsyncIterator()
                let c = client
                let cont = continuation
                Task {
                    await withReconnect(client: c, continuation: cont)
                }
            }
            return try await inner?.next()
        }
    }
}

@available(macOS 15.0, iOS 18.0, *)
private func withReconnect(
    client: Social_Mixi_Application_Service_ApplicationStream_V1_ApplicationService.ClientProtocol,
    continuation: AsyncThrowingStream<Mixi2Event, Error>.Continuation
) async {
    let maxRetries = 3
    var attempt = 0

    while attempt <= maxRetries {
        do {
            try await client.subscribeEvents(
                Social_Mixi_Application_Service_ApplicationStream_V1_SubscribeEventsRequest()
            ) { response in
                for try await message in response.messages {
                    for event in message.events {
                        if event.eventType == .ping {
                            continue
                        }
                        continuation.yield(event)
                    }
                }
            }
            // Stream completed cleanly
            continuation.finish()
            return
        } catch {
            if attempt >= maxRetries {
                continuation.finish(throwing: error)
                return
            }
            attempt += 1
            let delay = UInt64(1 << (attempt - 1)) * 1_000_000_000  // 1s, 2s, 4s
            try? await Task.sleep(nanoseconds: delay)
        }
    }
}
