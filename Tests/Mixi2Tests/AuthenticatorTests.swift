import Foundation
import Testing

@testable import Mixi2

@Suite("MockAuthenticator")
struct AuthenticatorTests {
    @Test("Returns configured token")
    func returnsToken() async throws {
        let auth = MockAuthenticator(token: "my-token")
        let token = try await auth.accessToken()
        #expect(token == "my-token")
    }

    @Test("Increments call count on each invocation")
    func tracksCallCount() async throws {
        let auth = MockAuthenticator(token: "tok")
        _ = try await auth.accessToken()
        _ = try await auth.accessToken()
        let count = await auth.callCount
        #expect(count == 2)
    }

    @Test("Throws configured error")
    func throwsError() async throws {
        let auth = MockAuthenticator(token: "", error: AuthError.tokenFetchFailed(statusCode: 401, body: ""))
        await #expect(throws: AuthError.self) {
            _ = try await auth.accessToken()
        }
    }
}
