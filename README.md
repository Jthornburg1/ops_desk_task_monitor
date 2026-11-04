# OpsDesk — Enterprise Task Monitor

A SwiftUI iOS prototype with Cognito hosted authentication, a task dashboard backed by JSONPlaceholder, and completion changes saved locally per account.

The dashboard includes task details, All/Completed/Pending filters, manual refresh, and loading, empty, and error states. **JSONPlaceholder is public: app login does not provide server-side API authorization.**

## Build and run

Developed and tested with **Xcode 27.2 (27B52)** and an **iPhone 17 Simulator running iOS 27.2**. The deployment target is iOS 27.2; older toolchains and other platforms have not been validated.

1. Open `OpsDesk.xcodeproj` from the repository root.
2. Allow Swift Package Manager to resolve dependencies using the included `Package.resolved`.
3. Select the **OpsDesk** scheme and a compatible iOS Simulator, then choose **Product → Run**.
4. Tap **Sign in** to open hosted login. Use an existing Cognito application account, or choose **Sign up**, use an email inbox you control, and complete any confirmation step.

Internet access is required for initial dependency resolution, authentication, and task loading. For a physical device, select your development team under Signing & Capabilities and adjust the bundle identifier if necessary. If your Derived Data location uses an external drive, connect it before building.

## Authentication setup

T`OpsDesk/Data/Authentication/CognitoConfiguration.swift`:

| Setting | Value |
| --- | --- |
| Region | `us-east-2` |
| User pool | `us-east-2_AWKUweltf` |
| App client | `5d57lsaksm98saqjat670nch9h` |
| Hosted domain | `us-east-2awkuweltf.auth.us-east-2.amazoncognito.com` |
| Callback / sign-out URLs | `opsdesk://callback` / `opsdesk://signout` |
| Flow / scopes | Authorization Code with PKCE / `openid`, `email` |

The app client has no secret. Amplify handles PKCE and secure token storage. Reviewers need a Cognito application account which can be created with a valid email address in the hosted Cognito UI. 

To use another pool, configure a public client without a secret, hosted login, the URLs/scopes above, and email read permission. Update `CognitoConfiguration.swift` and the domain in `CognitoUserInfoService.swift`. The `opsdesk` scheme is registered in `Configuration/Info.plist`. Changing pools also requires reconsidering the local-storage namespace.

Email comes from Cognito's OIDC `/oauth2/userInfo` endpoint using an SDK-provided access token. Missing email or lookup failure hides the label. The authenticated account ID, rather than email, scopes local storage.

## Architecture and decisions

```text
SwiftUI views → ViewModels → Domain service protocols → Data implementations
                                AuthService              Cognito / Amplify
                                TaskService              REST / DTO mapping
                                TaskCompletionService    UserDefaults
```

`AppDependencies` constructs live services and configures Amplify once. Presentation uses observable MainActor ViewModels. Domain contains models and service contracts without SwiftUI, Amplify, or URLSession dependencies. Data owns SDK integration, HTTP requests, DTO mapping, and persistence.

`RESTTaskService` concurrently fetches `/todos` and `/users`, validates HTTP responses, and associates tasks with users. Missing users have a fallback display. Both requests must succeed before publishing a new snapshot. Failed refresh preserves existing tasks; cancellation checks prevent cancelled task loads from publishing late results. Busy guards prevent overlapping refresh and authentication operations.

Amplify **2.63.0** is the main dependency, chosen to handle Cognito authentication and token management. URLSession and Codable handle the public API. Protocol injection supports testing without a dependency-injection framework or extra use-case layers.

## Sessions and local storage

Session checks run at launch, foreground activation, and explicit retry. The adapter checks Cognito token results because `isSignedIn` alone can remain true after expiry. Amplify refreshes tokens when possible. Confirmed expiry clears displayed identity and routes to sign-in; recovery resets SDK session state before hosted login. A failed reset offers retry.

Temporary verification failure is handled separately: startup offers a session-check retry, while an existing dashboard remains visible with a retry message. Successful local logout removes the dashboard; failed logout preserves the account. Incomplete provider logout can leave browser SSO available. Details: [SESSION_HANDLING.md](SESSION_HANDLING.md).

Completion toggles save explicit true/false overrides in UserDefaults under `taskCompletion.v1.<Cognito user ID>`. Overrides survive refresh, relaunch, and logout/login; accounts have separate storage and view state. Overrides are read after fetching, preserving toggles made during refresh. They continue to override server values until changed again. There is no reset-to-server action, cross-device sync, or offline task-list cache. These preferences are not credential storage.

No PUT/PATCH is sent because JSONPlaceholder simulates writes without persistence. See [COMPLETION_STORAGE.md](COMPLETION_STORAGE.md).

For a real API, use authenticated PATCH requests with optimistic updates, pending/confirmed state, and retry or rollback on failure. Use versions/ETags for conditional updates; conflicts should reload server state and offer resolution. Retrying writes needs idempotency rules.

## Tests and verification

Select **Product → Test** (`⌘U`) in Xcode, or run from the repository root after package resolution:

```sh
xcodebuild -project OpsDesk.xcodeproj -scheme OpsDesk \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' \
  -disableAutomaticPackageResolution -skipPackageUpdates \
  -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO test
```

Adjust the destination to an installed compatible simulator. Tests use Swift Testing, injected SDK/HTTP operations, and disposable UserDefaults suites. They do not perform live login or require the public API.

The latest run passed **44 tests in 10 suites** on November 4, 2026. Coverage includes authentication outcomes and overlap guards, token expiry/recovery, email requests, HTTP/decoding failures, task loading/filtering/cancellation, refresh recovery, persistence, and account isolation.

**Manual QA is in progress.** Fresh registration, live refresh-session expiry, device relaunch restoration, and two-account persistence still require recorded acceptance results. Automated storage reconstruction and SDK stubs do not establish those live outcomes.

## Limits and next improvements

- No continuous foreground expiry monitor or protected-API 401 recovery. Revocation may remain undetected until token refresh.
- Email failures are silent; configuration repeats the hosted domain in two files.
- No offline task cache, server synchronization, or conflict-resolution UI.
- Broader OS support, accessibility, Dynamic Type, and full UI acceptance testing need additional work.

## Enterprise evolution

For Entra ID with SAML federation, configure Entra as a SAML provider behind Cognito. The hosted browser handles SAML; the iOS app continues using OIDC with PKCE. Alternatively, direct Entra integration could replace the auth adapter with MSAL, with corresponding changes to identity scoping, logout, and enterprise policies.

Protected APIs need access tokens for their audience/scopes in a dedicated authenticated transport. The server must validate signature, issuer, audience, expiry, and permissions and enforce resource authorization. ID tokens should not authorize API calls. Coordinate refresh, retry safely once where appropriate, and distinguish expired credentials from insufficient permissions.

## AI assistance

I used AI tooling to accelerate the initial layout, using it as a force multiplier to rapidly explore and validate different technical approaches. Instead of accepting the raw outputs, I audited and refined the code to ensure it met our standards for security and edge-case handling. I mapped out the project's edge cases directly from the requirements document, drafting a technical specification to lock down my decisions. There were several instances where I consulted the Codex about what was the likely intent of portions of the requirements sheet. This allowed me to establish a rigorous, production-ready baseline before writing the core implementation. 

I chose to deviate from Codex's suggestion to use AuthO as the Authentication tool in favor of Amplify/Cognito. This was only because I have never used Cognito and was curious about the ease of implementing it. I also redirected the agent around some naming choices, layout, and a couple of coding choices.
