import Foundation
import Amplify
import AWSPluginsCore

/// Reads OIDC profile data using the scopes requested by hosted sign-in.
struct CognitoUserInfoService {
    let accessToken: () async throws -> String
    let transport: (URLRequest) async throws -> (Data, URLResponse)

    init(accessToken: @escaping () async throws -> String = {
        let session = try await Amplify.Auth.fetchAuthSession()
        guard let provider = session as? any AuthCognitoTokensProvider else {
            throw URLError(.userAuthenticationRequired)
        }
        return try provider.getCognitoTokens().get().accessToken
    }, transport: @escaping (URLRequest) async throws -> (Data, URLResponse) = {
        try await URLSession.shared.data(for: $0)
    }) {
        self.accessToken = accessToken
        self.transport = transport
    }

    func fetchAttributes() async throws -> [AuthUserAttribute] {
        let token = try await accessToken()
        guard !token.isEmpty,
              let url = URL(string: "https://us-east-2awkuweltf.auth.us-east-2.amazoncognito.com/oauth2/userInfo") else {
            throw URLError(.userAuthenticationRequired)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await transport(request)
        guard let response = response as? HTTPURLResponse,
              (200..<300).contains(response.statusCode) else {
            throw URLError(.badServerResponse)
        }
        let profile = try JSONDecoder().decode(Profile.self, from: data)
        guard let email = profile.email, !email.isEmpty else { return [] }
        return [AuthUserAttribute(.email, value: email)]
    }

    private struct Profile: Decodable {
        let email: String?
    }
}
