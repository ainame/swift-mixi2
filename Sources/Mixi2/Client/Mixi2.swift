import Foundation
import GRPCCore
import GRPCNIOTransportHTTP2
import Mixi2GRPC

/// A configured mixi2 gRPC client providing access to API and streaming services.
@available(macOS 15.0, iOS 18.0, *)
public final class Mixi2: Sendable {
    /// Configuration for connecting to the mixi2 gRPC endpoints.
    public struct Configuration: Sendable {
        public var apiHost: String
        public var streamHost: String
        public var port: Int
        public var authenticator: any Authenticator
        public var authKey: String?
        public var useTLS: Bool
        /// Raw Ed25519 public key bytes used by ``Bot`` in webhook mode.
        public var webhookPublicKey: Data?

        public init(
            apiHost: String,
            streamHost: String,
            port: Int = 443,
            authenticator: any Authenticator,
            authKey: String? = nil,
            useTLS: Bool = true,
            webhookPublicKey: Data? = nil,
        ) {
            self.apiHost = apiHost
            self.streamHost = streamHost
            self.port = port
            self.authenticator = authenticator
            self.authKey = authKey
            self.useTLS = useTLS
            self.webhookPublicKey = webhookPublicKey
        }
    }

    /// Selects which underlying gRPC connections ``run(_:)`` starts.
    public enum Service: Sendable {
        /// The unary API connection (required for `apiClient` RPCs).
        case api
        /// The server-streaming connection (required for `streamClient` / `EventStream`).
        case stream
    }

    public typealias APIClient = ApplicationService.Client<HTTP2ClientTransport.Posix>

    private let apiGRPCClient: GRPCClient<HTTP2ClientTransport.Posix>
    private let streamGRPCClient: GRPCClient<HTTP2ClientTransport.Posix>

    /// Client for the ApplicationService API (unary RPCs).
    public let apiClient: ApplicationService.Client<HTTP2ClientTransport.Posix>

    /// Client for the ApplicationService Stream (server-streaming RPCs).
    public let streamClient: StreamApplicationService.Client<HTTP2ClientTransport.Posix>

    public init(configuration: Configuration) throws {
        let transportSecurity: HTTP2ClientTransport.Posix.TransportSecurity =
            configuration.useTLS ? .tls : .plaintext
        let interceptor = AuthClientInterceptor(
            authenticator: configuration.authenticator,
            authKey: configuration.authKey,
        )

        let apiTransport = try HTTP2ClientTransport.Posix(
            target: .dns(host: configuration.apiHost, port: configuration.port),
            transportSecurity: transportSecurity,
        )
        let apiGRPCClient = GRPCClient(transport: apiTransport, interceptors: [interceptor])
        self.apiGRPCClient = apiGRPCClient
        apiClient = .init(wrapping: apiGRPCClient)

        let streamTransport = try HTTP2ClientTransport.Posix(
            target: .dns(host: configuration.streamHost, port: configuration.port),
            transportSecurity: transportSecurity,
        )
        let streamGRPCClient = GRPCClient(transport: streamTransport, interceptors: [interceptor])
        self.streamGRPCClient = streamGRPCClient
        streamClient = .init(wrapping: streamGRPCClient)
    }

    /// Runs the selected gRPC transport connections until shutdown.
    ///
    /// Must be called in a concurrent task alongside any RPC usage.
    /// Pass a subset when you only need one connection — e.g. `run([.api])` for webhook apps.
    public func run(_ services: Set<Service> = [.api, .stream]) async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            if services.contains(.api) {
                group.addTask { try await self.apiGRPCClient.runConnections() }
            }
            if services.contains(.stream) {
                group.addTask { try await self.streamGRPCClient.runConnections() }
            }
            try await group.waitForAll()
        }
    }

    /// Initiates graceful shutdown of both clients.
    public func shutdown() {
        apiGRPCClient.beginGracefulShutdown()
        streamGRPCClient.beginGracefulShutdown()
    }
}
