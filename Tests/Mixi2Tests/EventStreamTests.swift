import GRPCCore
import Mixi2GRPC
import Testing

@testable import Mixi2

/// A mock stream client that yields pre-configured responses.
final class MockStreamClient: Social_Mixi_Application_Service_ApplicationStream_V1_ApplicationService.ClientProtocol, Sendable {
    let responses: [Social_Mixi_Application_Model_V1_Event]
    let shouldFail: Bool

    init(events: [Social_Mixi_Application_Model_V1_Event], fail: Bool = false) {
        self.responses = events
        self.shouldFail = fail
    }

    func subscribeEvents<Result>(
        request: GRPCCore.ClientRequest<Social_Mixi_Application_Service_ApplicationStream_V1_SubscribeEventsRequest>,
        serializer: some GRPCCore.MessageSerializer<Social_Mixi_Application_Service_ApplicationStream_V1_SubscribeEventsRequest>,
        deserializer: some GRPCCore.MessageDeserializer<Social_Mixi_Application_Service_ApplicationStream_V1_SubscribeEventsResponse>,
        options: GRPCCore.CallOptions,
        onResponse handleResponse: @Sendable @escaping (GRPCCore.StreamingClientResponse<Social_Mixi_Application_Service_ApplicationStream_V1_SubscribeEventsResponse>) async throws -> Result
    ) async throws -> Result where Result: Sendable {
        if shouldFail {
            throw RPCError(code: .unavailable, message: "mock failure")
        }

        typealias BodyPart = StreamingClientResponse<Social_Mixi_Application_Service_ApplicationStream_V1_SubscribeEventsResponse>.Contents.BodyPart
        let eventsToSend = self.responses
        let bodyParts = RPCAsyncSequence<BodyPart, any Error>(
            wrapping: AsyncThrowingStream<BodyPart, Error> { continuation in
                var message = Social_Mixi_Application_Service_ApplicationStream_V1_SubscribeEventsResponse()
                message.events = eventsToSend
                continuation.yield(.message(message))
                continuation.yield(.trailingMetadata([:]))
                continuation.finish()
            }
        )
        let response = StreamingClientResponse<Social_Mixi_Application_Service_ApplicationStream_V1_SubscribeEventsResponse>(
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
        let pingEvent = Social_Mixi_Application_Model_V1_Event.with { $0.eventType = .ping }
        let realEvent = Social_Mixi_Application_Model_V1_Event.with {
            $0.eventID = "e1"
            $0.eventType = .postCreated
        }
        let client = MockStreamClient(events: [pingEvent, realEvent])
        let stream = EventStream(client: client)

        var received: [Mixi2Event] = []
        for try await event in stream {
            received.append(event)
        }

        #expect(received.count == 1)
        #expect(received[0].eventID == "e1")
    }

    @Test("Filters all PING events")
    func filtersAllPingEvents() async throws {
        guard #available(macOS 15.0, iOS 18.0, *) else { return }
        let events = [
            Social_Mixi_Application_Model_V1_Event.with { $0.eventType = .ping },
            Social_Mixi_Application_Model_V1_Event.with { $0.eventType = .ping },
        ]
        let client = MockStreamClient(events: events)
        let stream = EventStream(client: client)

        var received: [Mixi2Event] = []
        for try await event in stream {
            received.append(event)
        }

        #expect(received.isEmpty)
    }

    @Test("Yields multiple events from single response")
    func yieldsMultipleEvents() async throws {
        guard #available(macOS 15.0, iOS 18.0, *) else { return }
        let events = (1...3).map { i in
            Social_Mixi_Application_Model_V1_Event.with {
                $0.eventID = "e\(i)"
                $0.eventType = .postCreated
            }
        }
        let client = MockStreamClient(events: events)
        let stream = EventStream(client: client)

        var received: [Mixi2Event] = []
        for try await event in stream {
            received.append(event)
        }

        #expect(received.count == 3)
        #expect(received.map(\.eventID) == ["e1", "e2", "e3"])
    }
}
