import Crypto
import Foundation
@testable import Mixi2
import Mixi2GRPC
import SwiftProtobuf
import Testing

@Suite("WebhookHandler")
struct WebhookHandlerTests {
    // Ed25519 keypair for tests
    private let privateKey = Curve25519.Signing.PrivateKey()
    private var publicKey: Curve25519.Signing.PublicKey {
        privateKey.publicKey
    }

    private func makeHandler() throws -> WebhookHandler {
        try WebhookHandler(publicKey: publicKey)
    }

    private func sign(body: Data, timestamp: String) throws -> String {
        let data = body + Data(timestamp.utf8)
        let signature = try privateKey.signature(for: data)
        return Data(signature).base64EncodedString()
    }

    private func makeBody(events: [Event]) throws -> Data {
        var req = SendEventRequest()
        req.events = events
        return try req.serializedData()
    }

    @Test("Accepts valid signature and returns non-ping events")
    func acceptsValidSignature() throws {
        let event = Event.with {
            $0.eventID = "evt-1"
            $0.eventType = .postCreated
        }
        let timestamp = String(Int64(Date.now.timeIntervalSince1970))
        let body = try makeBody(events: [event])
        let signature = try sign(body: body, timestamp: timestamp)

        let handler = try makeHandler()
        let events = try handler.handle(body: body, signature: signature, timestamp: timestamp)
        #expect(events.count == 1)
        #expect(events[0].eventID == "evt-1")
    }

    @Test("Filters out PING events")
    func filtersPingEvents() throws {
        let pingEvent = Event.with { $0.eventType = .ping }
        let realEvent = Event.with {
            $0.eventID = "evt-2"
            $0.eventType = .chatMessageReceived
        }
        let timestamp = String(Int64(Date.now.timeIntervalSince1970))
        let body = try makeBody(events: [pingEvent, realEvent])
        let signature = try sign(body: body, timestamp: timestamp)

        let handler = try makeHandler()
        let events = try handler.handle(body: body, signature: signature, timestamp: timestamp)
        #expect(events.count == 1)
        #expect(events[0].eventID == "evt-2")
    }

    @Test("Rejects invalid signature")
    func rejectsInvalidSignature() throws {
        let body = try makeBody(events: [])
        let timestamp = String(Int64(Date.now.timeIntervalSince1970))
        let badSignature = Data(repeating: 0, count: 64).base64EncodedString()

        let handler = try makeHandler()
        #expect(throws: WebhookError.signatureInvalid) {
            _ = try handler.handle(body: body, signature: badSignature, timestamp: timestamp)
        }
    }

    @Test("Rejects non-base64 signature")
    func rejectsInvalidBase64Signature() throws {
        let body = try makeBody(events: [])
        let timestamp = String(Int64(Date.now.timeIntervalSince1970))

        let handler = try makeHandler()
        #expect(throws: WebhookError.invalidSignatureEncoding) {
            _ = try handler.handle(body: body, signature: "not-valid-base64!!!", timestamp: timestamp)
        }
    }

    @Test("Rejects timestamp too old (>300s)")
    func rejectsOldTimestamp() throws {
        let body = try makeBody(events: [])
        let oldTimestamp = String(Int64(Date.now.timeIntervalSince1970) - 301)
        let signature = try sign(body: body, timestamp: oldTimestamp)

        let handler = try makeHandler()
        #expect(throws: WebhookError.timestampTooOld) {
            _ = try handler.handle(body: body, signature: signature, timestamp: oldTimestamp)
        }
    }

    @Test("Rejects timestamp in future (>300s)")
    func rejectsFutureTimestamp() throws {
        let body = try makeBody(events: [])
        let futureTimestamp = String(Int64(Date.now.timeIntervalSince1970) + 301)
        let signature = try sign(body: body, timestamp: futureTimestamp)

        let handler = try makeHandler()
        #expect(throws: WebhookError.timestampInFuture) {
            _ = try handler.handle(body: body, signature: signature, timestamp: futureTimestamp)
        }
    }

    @Test("Rejects non-numeric timestamp")
    func rejectsNonNumericTimestamp() throws {
        let body = try makeBody(events: [])

        let handler = try makeHandler()
        #expect(throws: WebhookError.invalidTimestamp) {
            _ = try handler.handle(body: body, signature: "dGVzdA==", timestamp: "not-a-number")
        }
    }

    @Test("Accepts timestamp within tolerance boundary (±300s)")
    func acceptsBoundaryTimestamp() throws {
        let event = Event.with { $0.eventType = .postCreated }
        let body = try makeBody(events: [event])

        // 299 seconds old — still valid
        let timestamp = String(Int64(Date.now.timeIntervalSince1970) - 299)
        let signature = try sign(body: body, timestamp: timestamp)

        let handler = try makeHandler()
        let events = try handler.handle(body: body, signature: signature, timestamp: timestamp)
        #expect(events.count == 1)
    }
}
