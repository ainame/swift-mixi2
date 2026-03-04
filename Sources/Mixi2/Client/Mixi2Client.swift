import Configuration
import Foundation
import GRPCCore
import GRPCNIOTransportHTTP2
import Mixi2GRPC

/// A configured mixi2 gRPC client providing access to API and streaming services.
@available(macOS 15.0, iOS 18.0, *)
public final class Mixi2Client: Sendable {
    /// Configuration for connecting to the mixi2 gRPC endpoint.
    public struct Configuration: Sendable {
        public var host: String
        public var port: Int
        public var authenticator: any Authenticator
        public var authKey: String?
        public var useTLS: Bool

        public init(
            host: String,
            port: Int = 443,
            authenticator: any Authenticator,
            authKey: String? = nil,
            useTLS: Bool = true
        ) {
            self.host = host
            self.port = port
            self.authenticator = authenticator
            self.authKey = authKey
            self.useTLS = useTLS
        }

        /// Reads configuration using the provided `ConfigReader`.
        ///
        /// Keys (mapped to env vars by default): `mixi2.api.host` → `MIXI2_API_HOST`,
        /// `mixi2.client.id` → `MIXI2_CLIENT_ID`, `mixi2.client.secret` → `MIXI2_CLIENT_SECRET`,
        /// `mixi2.token.url` → `MIXI2_TOKEN_URL`, and optionally `mixi2.auth.key` → `MIXI2_AUTH_KEY`,
        /// `mixi2.api.port` → `MIXI2_API_PORT`.
        public static func fromEnvironment(
            using config: ConfigReader = ConfigReader(provider: EnvironmentVariablesProvider())
        ) throws -> Configuration {
            guard let host = config.string(forKey: "mixi2.api.host") else {
                throw ConfigurationError.missingKey("mixi2.api.host")
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
            return Configuration(host: host, port: port, authenticator: authenticator, authKey: authKey)
        }
    }

    private let grpcClient: GRPCClient<HTTP2ClientTransport.Posix>

    /// Client for the ApplicationService API (unary RPCs).
    public let apiClient: Social_Mixi_Application_Service_ApplicationApi_V1_ApplicationService.Client<HTTP2ClientTransport.Posix>

    /// Client for the ApplicationService Stream (server-streaming RPCs).
    public let streamClient: Social_Mixi_Application_Service_ApplicationStream_V1_ApplicationService.Client<HTTP2ClientTransport.Posix>

    public init(configuration: Configuration) throws {
        let transportSecurity: HTTP2ClientTransport.Posix.TransportSecurity =
            configuration.useTLS ? .tls : .plaintext
        let transport = try HTTP2ClientTransport.Posix(
            target: .dns(host: configuration.host, port: configuration.port),
            transportSecurity: transportSecurity
        )
        let interceptor = AuthClientInterceptor(
            authenticator: configuration.authenticator,
            authKey: configuration.authKey
        )
        let client = GRPCClient(transport: transport, interceptors: [interceptor])
        self.grpcClient = client
        self.apiClient = .init(wrapping: client)
        self.streamClient = .init(wrapping: client)
    }

    /// Runs the underlying gRPC transport connection until shutdown.
    ///
    /// Must be called in a concurrent task alongside any RPC usage.
    public func run() async throws {
        try await grpcClient.runConnections()
    }

    /// Initiates graceful shutdown of the client.
    public func shutdown() {
        grpcClient.beginGracefulShutdown()
    }
}

public enum ConfigurationError: Error, Sendable {
    case missingKey(String)
}
