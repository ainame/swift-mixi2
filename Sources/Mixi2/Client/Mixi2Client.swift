import Configuration
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

        /// Reads configuration using the provided `ConfigReader`.
        ///
        /// Keys (mapped to env vars by default): `mixi2.api.host` → `MIXI2_API_HOST`,
        /// `mixi2.stream.host` → `MIXI2_STREAM_HOST`,
        /// `mixi2.client.id` → `MIXI2_CLIENT_ID`, `mixi2.client.secret` → `MIXI2_CLIENT_SECRET`,
        /// `mixi2.token.url` → `MIXI2_TOKEN_URL`, and optionally `mixi2.auth.key` → `MIXI2_AUTH_KEY`,
        /// `mixi2.api.port` → `MIXI2_API_PORT`.
        public static func fromEnvironment(
            using config: ConfigReader = ConfigReader(provider: EnvironmentVariablesProvider())
        ) throws -> Configuration {
            guard let apiHost = config.string(forKey: "mixi2.api.host") else {
                throw ConfigurationError.missingKey("mixi2.api.host")
            }
            guard let streamHost = config.string(forKey: "mixi2.stream.host") else {
                throw ConfigurationError.missingKey("mixi2.stream.host")
            }
            guard let clientID = config.string(forKey: "mixi2.client.id") else {
                throw ConfigurationError.missingKey("mixi2.client.id")
            }
            guard let clientSecret = config.string(forKey: "mixi2.client.secret") else {
                throw ConfigurationError.missingKey("mixi2.client.secret")
            }
            guard let tokenURL = config.string(forKey: "mixi2.token.url", as: URL.self) else {
                throw ConfigurationError.missingKey("mixi2.token.url")
            }
            let port = config.int(forKey: "mixi2.api.port", default: 443)
            let authKey = config.string(forKey: "mixi2.auth.key")
            let authenticator = ClientCredentialsAuthenticator(
                clientID: clientID,
                clientSecret: clientSecret,
                tokenURL: tokenURL
            )
            return Configuration(apiHost: apiHost, streamHost: streamHost, port: port, authenticator: authenticator, authKey: authKey)
        }
    }

    private let apiGRPCClient: GRPCClient<HTTP2ClientTransport.Posix>
    private let streamGRPCClient: GRPCClient<HTTP2ClientTransport.Posix>

    /// Client for the ApplicationService API (unary RPCs).
    public let apiClient: Social_Mixi_Application_Service_ApplicationApi_V1_ApplicationService.Client<HTTP2ClientTransport.Posix>

    /// Client for the ApplicationService Stream (server-streaming RPCs).
    public let streamClient: Social_Mixi_Application_Service_ApplicationStream_V1_ApplicationService.Client<HTTP2ClientTransport.Posix>

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
        self.apiClient = .init(wrapping: apiGRPCClient)

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

public enum ConfigurationError: Error, Sendable {
    case missingKey(String)
}
