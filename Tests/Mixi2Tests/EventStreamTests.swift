import GRPCCore
import Mixi2GRPC
import Testing

@testable import Mixi2

/// A mock stream client that yields pre-configured responses.
final class MockStreamClient: Mixi2StreamApplicationService.ClientProtocol, Sendable {
    let responses: [Mixi2Event]
    let shouldFail: Bool

    init(events: [Mixi2Event], fail: Bool = false) {
        self.responses = events
        self.shouldFail = fail
    }

    func subscribeEvents<Result>(
        request: GRPCCore.ClientRequest<Mixi2StreamSubscribeEventsRequest>,
        serializer: some GRPCCore.MessageSerializer<Mixi2StreamSubscribeEventsRequest>,
        deserializer: some GRPCCore.MessageDeserializer<Mixi2StreamSubscribeEventsResponse>,
        options: GRPCCore.CallOptions,
        onResponse handleResponse: @Sendable @escaping (GRPCCore.StreamingClientResponse<Mixi2StreamSubscribeEventsResponse>) async throws -> Result
    ) async throws -> Result where Result: Sendable {
        if shouldFail {
            throw RPCError(code: .unavailable, message: "mock failure")
        }

        typealias BodyPart = StreamingClientResponse<Mixi2StreamSubscribeEventsResponse>.Contents.BodyPart
        let eventsToSend = self.responses
        let bodyParts = RPCAsyncSequence<BodyPart, any Error>(
            wrapping: AsyncThrowingStream<BodyPart, Error> { continuation in
                var message = Mixi2StreamSubscribeEventsResponse()
                message.events = eventsToSend
                continuation.yield(.message(message))
                continuation.yield(.trailingMetadata([:]))
                continuation.finish()
            }
        )
        let response = StreamingClientResponse<Mixi2StreamSubscribeEventsResponse>(
            metadata: [:],
            bodyParts: bodyParts
        )
        return try await handleResponse(response)
    }
}

@Suite("EventStream")
struct EventStreamTests {
    @Test("Yields non-ping events from stream")
    func yieldsNonPingEvents() async throws {
        guard #available(macOS 15.0, iOS 18.0, *) else { return }
        let pingEvent = Mixi2Event.with { $0.eventType = .ping }
        let realEvent = Mixi2Event.with {
            $0.eventID = "e1"
            $0.eventType = .postCreated
        }
        let client = MockStreamClient(events: [pingEvent, realEvent])
        let stream = EventStream(client: client)

        var received: [Mixi2Event] = []
        try await stream.run { received.append($0) }

        #expect(received.count == 1)
        #expect(received[0].eventID == "e1")
    }

    @Test("Filters all PING events")
    func filtersAllPingEvents() async throws {
        guard #available(macOS 15.0, iOS 18.0, *) else { return }
        let events = [
            Mixi2Event.with { $0.eventType = .ping },
            Mixi2Event.with { $0.eventType = .ping },
        ]
        let client = MockStreamClient(events: events)
        let stream = EventStream(client: client)

        var received: [Mixi2Event] = []
        try await stream.run { received.append($0) }

        #expect(received.isEmpty)
    }

    @Test("Yields multiple events from single response")
    func yieldsMultipleEvents() async throws {
        guard #available(macOS 15.0, iOS 18.0, *) else { return }
        let events = (1...3).map { i in
            Mixi2Event.with {
                $0.eventID = "e\(i)"
                $0.eventType = .postCreated
            }
        }
        let client = MockStreamClient(events: events)
        let stream = EventStream(client: client)

        var received: [Mixi2Event] = []
        try await stream.run { received.append($0) }

        #expect(received.count == 3)
        #expect(received.map(\.eventID) == ["e1", "e2", "e3"])
    }
}
