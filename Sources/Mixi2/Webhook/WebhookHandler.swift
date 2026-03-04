import Crypto
import Foundation
import Mixi2GRPC
import SwiftProtobuf

/// Verifies and parses mixi2 webhook payloads.
///
/// Usage:
/// ```swift
/// let handler = try WebhookHandler(publicKeyBytes: rawPublicKeyBytes)
/// let events = try handler.handle(body: requestBody, signature: signatureHeader, timestamp: timestampHeader)
/// ```
public struct WebhookHandler: Sendable {
    private static let timestampTolerance: TimeInterval = 300

    private let publicKey: Curve25519.Signing.PublicKey

    /// Creates a handler with the given Ed25519 public key bytes.
    public init(publicKeyBytes: some ContiguousBytes) throws {
        publicKey = try Curve25519.Signing.PublicKey(rawRepresentation: publicKeyBytes)
    }

    /// Creates a handler with the given Ed25519 public key.
    public init(publicKey: Curve25519.Signing.PublicKey) {
        self.publicKey = publicKey
    }

    /// Verifies and parses an incoming webhook request.
    ///
    /// - Parameters:
    ///   - body: The raw request body bytes.
    ///   - signature: The value of the `x-mixi2-application-event-signature` header (base64-encoded).
    ///   - timestamp: The value of the `x-mixi2-application-event-timestamp` header (Unix timestamp string).
    /// - Returns: Non-ping events from the payload.
    /// - Throws: `WebhookError` for any verification failure.
    public func handle(
        body: Data,
        signature signatureHeader: String,
        timestamp timestampHeader: String
    ) throws -> [Mixi2Event] {
        // Decode signature
        guard let signatureBytes = Data(base64Encoded: signatureHeader) else {
            throw WebhookError.invalidSignatureEncoding
        }

        // Validate timestamp
        guard let unixTime = Int64(timestampHeader) else {
            throw WebhookError.invalidTimestamp
        }
        let diff = Date.now.timeIntervalSince1970 - Double(unixTime)
        if diff > Self.timestampTolerance {
            throw WebhookError.timestampTooOld
        }
        if diff < -Self.timestampTolerance {
            throw WebhookError.timestampInFuture
        }

        // Verify signature over body + timestamp
        let dataToVerify = body + Data(timestampHeader.utf8)
        guard publicKey.isValidSignature(signatureBytes, for: dataToVerify) else {
            throw WebhookError.signatureInvalid
        }

        // Deserialize protobuf
        let request = try Mixi2SendEventRequest(
            serializedBytes: body
        )

        // Filter out PING events
        return request.events.filter { $0.eventType != .ping }
    }
}

/// Errors that can occur during webhook verification.
public enum WebhookError: Error, Sendable {
    case invalidSignatureEncoding
    case invalidTimestamp
    case timestampTooOld
    case timestampInFuture
    case signatureInvalid
    case protobufDeserializationFailed
}
