import Foundation
import Mixi2

/// A mock `Authenticator` for use in tests.
actor MockAuthenticator: Authenticator {
    var tokenToReturn: String
    var errorToThrow: Error?
    var callCount = 0

    init(token: String = "mock-token", error: Error? = nil) {
        self.tokenToReturn = token
        self.errorToThrow = error
    }

    func accessToken() async throws -> String {
        callCount += 1
        if let error = errorToThrow {
            throw error
        }
        return tokenToReturn
    }
}
