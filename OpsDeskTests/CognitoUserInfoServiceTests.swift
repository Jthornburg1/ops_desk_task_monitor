import Amplify
import Foundation
import Testing
@testable import OpsDesk

@MainActor
struct CognitoUserInfoServiceTests {
    @Test
    func requestsOIDCProfileWithBearerToken() async throws {
        var requests = 0
        let service = CognitoUserInfoService(accessToken: { "test-access-token" }, transport: { request in
            requests += 1
            #expect(request.url?.absoluteString == "https://us-east-2awkuweltf.auth.us-east-2.amazoncognito.com/oauth2/userInfo")
            #expect(request.httpMethod == "GET")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-access-token")
            return (Data(#"{"sub":"test-subject","email":"user@example.com"}"#.utf8),
                    HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        })
        let attributes = try await service.fetchAttributes()
        #expect(requests == 1)
        #expect(attributes.first(where: { $0.key == .email })?.value == "user@example.com")
    }

    @Test
    func rejectsHTTPFailureBeforeDecodingProfile() async {
        let service = CognitoUserInfoService(accessToken: { "test-access-token" }, transport: { request in
            (Data(#"{"email":"must-not-display@example.com"}"#.utf8),
             HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!)
        })
        await #expect(throws: (any Error).self) { try await service.fetchAttributes() }
    }
}
