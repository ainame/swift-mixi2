import GRPCCore
import Mixi2GRPC

/// Connects to the mixi2 event stream and dispatches non-ping events to a handler.
///
/// PING events are automatically filtered. On connection failure the stream retries
/// up to 3 times with 1s/2s/4s exponential backoff before propagating the error.
///
/// The reconnect producer and the event consumer run as structured child tasks inside
/// a `withThrowingTaskGroup` — cancellation propagates automatically from the parent
/// task with no manual wiring required.
@available(macOS 15.0, iOS 18.0, *)
public struct EventStream: Sendable {
    private let client: Mixi2StreamApplicationService.ClientProtocol

    public init(client: Mixi2StreamApplicationService.ClientProtocol) {
        self.client = client
    }

    /// Subscribes to the event stream and calls `body` for each incoming event.
    ///
    /// Returns when the stream ends cleanly, or throws if retries are exhausted or
    /// the parent task is cancelled.
    public func run(
        _ body: (Mixi2Event) async throws -> Void
    ) async throws {
        let (stream, continuation) = AsyncThrowingStream<Mixi2Event, Error>.makeStream()
        try await withThrowingTaskGroup(of: Void.self) { group in
            // Producer: structured child task — cancelled automatically when group exits.
            group.addTask {
                await withReconnect(client: self.client, continuation: continuation)
            }
            // Consumer: runs in the group body on the same structured scope.
            for try await event in stream {
                try await body(event)
            }
            // Stream ended cleanly — cancel the producer child task.
            group.cancelAll()
        }
    }
}

@available(macOS 15.0, iOS 18.0, *)
@concurrent
private func withReconnect(
    client: Mixi2StreamApplicationService.ClientProtocol,
    continuation: AsyncThrowingStream<Mixi2Event, Error>.Continuation
) async {
    let maxRetries = 3
    var attempt = 0

    while attempt <= maxRetries {
        do {
            try await client.subscribeEvents(
                Mixi2StreamSubscribeEventsRequest()
            ) { response in
                for try await message in response.messages {
                    for event in message.events {
                        if event.eventType == .ping { continue }
                        continuation.yield(event)
                    }
                }
            }
            continuation.finish()
            return
        } catch is CancellationError {
            // Task was cancelled — stop retrying cleanly without propagating the error.
            continuation.finish()
            return
        } catch {
            if attempt >= maxRetries {
                continuation.finish(throwing: error)
                return
            }
            attempt += 1
            do {
                try await Task.sleep(for: .seconds(1 << (attempt - 1)))  // 1s, 2s, 4s
            } catch {
                // Cancelled during backoff — stop retrying cleanly.
                continuation.finish()
                return
            }
        }
    }
}
