import Amplify
import AWSCognitoAuthPlugin

@MainActor
enum CognitoConfiguration {
    static func configure() throws {
        // Public mobile-client configuration; no client secret or identity pool is needed.
        let pluginConfiguration: JSONValue = [
            "CognitoUserPool": [
                "Default": [
                    "PoolId": "us-east-2_AWKUweltf",
                    "AppClientId": "5d57lsaksm98saqjat670nch9h",
                    "Region": "us-east-2"
                ]
            ],
            "Auth": [
                "Default": [
                    "OAuth": [
                        "WebDomain": "us-east-2awkuweltf.auth.us-east-2.amazoncognito.com",
                        "AppClientId": "5d57lsaksm98saqjat670nch9h",
                        "SignInRedirectURI": "opsdesk://callback",
                        "SignOutRedirectURI": "opsdesk://signout",
                        "Scopes": ["openid", "email"]
                    ]
                ]
            ]
        ]
        let configuration = AmplifyConfiguration(auth: AuthCategoryConfiguration(
            plugins: ["awsCognitoAuthPlugin": pluginConfiguration]
        ))

        try Amplify.add(plugin: AuthStageDiagnostic())
        try Amplify.add(plugin: AWSCognitoAuthPlugin())
        try Amplify.configure(configuration)
    }
}
