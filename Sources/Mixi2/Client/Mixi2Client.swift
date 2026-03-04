import Foundation
import GRPCCore
import GRPCNIOTransportHTTP2
import Mixi2GRPC

/// A configured mixi2 gRPC client providing access to API and streaming services.
@available(macOS 15.0, iOS 18.0, *)
public final class Mixi2Client: Sendable {
    /// Configuration for connecting to the mixi2 gRPC endpoints.
    public struct Configuration: Sendable {
        public var apiHost: String
        public var streamHost: String
        public var port: Int
        public var authenticator: any Authenticator
        public var authKey: String?
        public var useTLS: Bool

        public init(
            apiHost: String,
            streamHost: String,
            port: Int = 443,
            authenticator: any Authenticator,
            authKey: String? = nil,
            useTLS: Bool = true
        ) {
            self.apiHost = apiHost
            self.streamHost = streamHost
            self.port = port
            self.authenticator = authenticator
            self.authKey = authKey
            self.useTLS = useTLS
        }
    }

    public typealias ApplicationServiceClient = ApplicationService.Client<HTTP2ClientTransport.Posix>

    private let apiGRPCClient: GRPCClient<HTTP2ClientTransport.Posix>
    private let streamGRPCClient: GRPCClient<HTTP2ClientTransport.Posix>

    /// Client for the ApplicationService API (unary RPCs).
    public let applicationService: ApplicationService.Client<HTTP2ClientTransport.Posix>

    /// Client for the ApplicationService Stream (server-streaming RPCs).
    public let streamClient: StreamApplicationService.Client<HTTP2ClientTransport.Posix>

    public init(configuration: Configuration) throws {
        let transportSecurity: HTTP2ClientTransport.Posix.TransportSecurity =
            configuration.useTLS ? .tls : .plaintext
        let interceptor = AuthClientInterceptor(
            authenticator: configuration.authenticator,
            authKey: configuration.authKey
        )

        let apiTransport = try HTTP2ClientTransport.Posix(
            target: .dns(host: configuration.apiHost, port: configuration.port),
            transportSecurity: transportSecurity
        )
        let apiGRPCClient = GRPCClient(transport: apiTransport, interceptors: [interceptor])
        self.apiGRPCClient = apiGRPCClient
        self.applicationService = .init(wrapping: apiGRPCClient)

        let streamTransport = try HTTP2ClientTransport.Posix(
            target: .dns(host: configuration.streamHost, port: configuration.port),
            transportSecurity: transportSecurity
        )
        let streamGRPCClient = GRPCClient(transport: streamTransport, interceptors: [interceptor])
        self.streamGRPCClient = streamGRPCClient
        self.streamClient = .init(wrapping: streamGRPCClient)
    }

    /// Runs the underlying gRPC transport connections until shutdown.
    ///
    /// Must be called in a concurrent task alongside any RPC usage.
    public func run() async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask { try await self.apiGRPCClient.runConnections() }
            group.addTask { try await self.streamGRPCClient.runConnections() }
            try await group.waitForAll()
        }
    }

    /// Initiates graceful shutdown of both clients.
    public func shutdown() {
        apiGRPCClient.beginGracefulShutdown()
        streamGRPCClient.beginGracefulShutdown()
    }
}
