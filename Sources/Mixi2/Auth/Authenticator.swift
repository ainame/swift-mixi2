import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Provides OAuth2 access tokens for mixi2 API authentication.
public protocol Authenticator: Sendable {
    /// Returns a valid access token, refreshing if necessary.
    func accessToken() async throws -> String
}

/// OAuth2 Client Credentials authenticator with actor-isolated token caching.
///
/// Fetches tokens using the Client Credentials flow and caches them until
/// 60 seconds before expiry to avoid unnecessary refreshes.
public actor ClientCredentialsAuthenticator: Authenticator {
    private let clientID: String
    private let clientSecret: String
    private let tokenURL: URL

    private var cachedToken: String?
    private var bufferedExpiresAt: Date?

    public init(clientID: String, clientSecret: String, tokenURL: URL) {
        self.clientID = clientID
        self.clientSecret = clientSecret
        self.tokenURL = tokenURL
    }

    public func accessToken() async throws -> String {
        if let token = cachedToken, let expiry = bufferedExpiresAt, Date.now < expiry {
            return token
        }
        return try await fetchToken()
    }

    private func fetchToken() async throws -> String {
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let allowed = CharacterSet.alphanumerics.union(.init(charactersIn: "-._~"))
        let encodedID = clientID.addingPercentEncoding(withAllowedCharacters: allowed) ?? clientID
        let encodedSecret = clientSecret.addingPercentEncoding(withAllowedCharacters: allowed) ?? clientSecret
        let body = "grant_type=client_credentials&client_id=\(encodedID)&client_secret=\(encodedSecret)"
        request.httpBody = Data(body.utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "<non-utf8>"
            throw AuthError.tokenFetchFailed(statusCode: (response as? HTTPURLResponse)?.statusCode ?? -1, body: body)
        }

        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
        cachedToken = tokenResponse.accessToken
        bufferedExpiresAt = Date.now.addingTimeInterval(Double(tokenResponse.expiresIn) - 60)
        return tokenResponse.accessToken
    }
}

private struct TokenResponse: Decodable {
    let accessToken: String
    let expiresIn: Int

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case expiresIn = "expires_in"
    }
}

public enum AuthError: Error, Sendable {
    case tokenFetchFailed(statusCode: Int, body: String)
}
