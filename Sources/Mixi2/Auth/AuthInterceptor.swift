import GRPCCore

/// gRPC client interceptor that injects Bearer token and optional x-auth-key metadata.
@available(gRPCSwift 2.0, *)
public struct AuthClientInterceptor: ClientInterceptor {
    private let authenticator: any Authenticator
    private let authKey: String?

    public init(authenticator: any Authenticator, authKey: String? = nil) {
        self.authenticator = authenticator
        self.authKey = authKey
    }

    @concurrent
    public func intercept<Input: Sendable, Output: Sendable>(
        request: StreamingClientRequest<Input>,
        context: ClientContext,
        next: @concurrent (
            _ request: StreamingClientRequest<Input>,
            _ context: ClientContext
        ) async throws -> StreamingClientResponse<Output>
    ) async throws -> StreamingClientResponse<Output> {
        var request = request
        let token = try await authenticator.accessToken()
        request.metadata.replaceOrAddString("Bearer \(token)", forKey: "authorization")
        if let key = authKey {
            request.metadata.replaceOrAddString(key, forKey: "x-auth-key")
        }
        return try await next(request, context)
    }
}
