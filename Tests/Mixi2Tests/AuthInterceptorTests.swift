import GRPCCore
@testable import Mixi2
import Testing

private struct StopError: Error {}
private struct DummyMessage: Sendable {}

@Suite("AuthClientInterceptor")
struct AuthInterceptorTests {
    private func makeContext() -> ClientContext {
        let service = ServiceDescriptor(
            fullyQualifiedService: "social.mixi.application.service.application_api.v1.ApplicationService",
        )
        return ClientContext(
            descriptor: MethodDescriptor(service: service, method: "GetUsers"),
            remotePeer: "localhost",
            localPeer: "localhost",
        )
    }

    /// Invokes the interceptor and returns the metadata seen by `next`.
    private func captureMetadata(
        interceptor: AuthClientInterceptor,
        metadata: Metadata = [:],
    ) async throws -> Metadata {
        let request = StreamingClientRequest<DummyMessage>(metadata: metadata) { _ in }
        let context = makeContext()
        var captured: Metadata = [:]
        do {
            _ = try await interceptor.intercept(
                request: request,
                context: context,
            ) { (req: StreamingClientRequest<DummyMessage>, _) -> StreamingClientResponse<DummyMessage> in
                captured = req.metadata
                throw StopError()
            }
        } catch is StopError {}
        return captured
    }

    @Test("Injects Bearer authorization header")
    func injectsBearerToken() async throws {
        let auth = MockAuthenticator(token: "test-token-abc")
        let interceptor = AuthClientInterceptor(authenticator: auth)
        let metadata = try await captureMetadata(interceptor: interceptor)
        var iterator = metadata[stringValues: "authorization"].makeIterator()
        let authValue = iterator.next()
        #expect(authValue == "Bearer test-token-abc")
    }

    @Test("Injects x-auth-key header when provided")
    func injectsAuthKey() async throws {
        let auth = MockAuthenticator(token: "tok")
        let interceptor = AuthClientInterceptor(authenticator: auth, authKey: "my-secret-key")
        let metadata = try await captureMetadata(interceptor: interceptor)
        var iterator = metadata[stringValues: "x-auth-key"].makeIterator()
        let keyValue = iterator.next()
        #expect(keyValue == "my-secret-key")
    }

    @Test("Does not inject x-auth-key when nil")
    func omitsAuthKeyWhenNil() async throws {
        let auth = MockAuthenticator(token: "tok")
        let interceptor = AuthClientInterceptor(authenticator: auth)
        let metadata = try await captureMetadata(interceptor: interceptor)
        var iterator = metadata[stringValues: "x-auth-key"].makeIterator()
        let keyValue = iterator.next()
        #expect(keyValue == nil)
    }

    @Test("Propagates authentication error")
    func propagatesAuthError() async throws {
        let auth = MockAuthenticator(token: "", error: AuthError.tokenFetchFailed(statusCode: 401, body: ""))
        let interceptor = AuthClientInterceptor(authenticator: auth)
        let request = StreamingClientRequest<DummyMessage>(metadata: [:]) { _ in }
        let context = makeContext()
        await #expect(throws: AuthError.self) {
            _ = try await interceptor.intercept(
                request: request,
                context: context,
            ) { (_: StreamingClientRequest<DummyMessage>, _) -> StreamingClientResponse<DummyMessage> in
                throw StopError()
            }
        }
    }
}
