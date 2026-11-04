# Local task completion

Open a task and use the Completed switch to mark it completed or pending. The dashboard and its filters reflect the change immediately. No PUT/PATCH is sent: JSONPlaceholder simulates writes without persisting them.

UserDefaults stores only task-ID-to-Boolean overrides under `taskCompletion.v1.<Cognito user ID>`. The identity comes from Amplify's current user, not the task's assigned user or an email address. The dashboard is unavailable until a nonempty authenticated identity is resolved; there is no shared fallback key. Changing accounts recreates the signed-in view tree with the new account's storage.

Overrides are reapplied after refresh and survive app termination/relaunch. Logout clears the active in-memory identity and removes the dashboard; the saved overrides remain for the same account's next sign-in. They are device-local, not synced between devices or saved to the API. They are ordinary app preferences, not encrypted credentials or an authorization boundary. Tokens remain managed by Amplify. Removing the app's preferences removes the overrides.

A saved false value is an explicit pending override, not an absent override. Local overrides continue to win over later API values until changed again. There is currently no reset-to-server UI or conflict resolution. The task list itself is not cached for offline relaunch.

Tests use unique, disposable UserDefaults suites rather than real app preferences. Coverage includes saving both statuses, restoring a new model/store, refresh, filtering, account isolation, and refusing access without an account ID.

For a real API, use an authenticated PATCH for `completed`, apply the change optimistically, and expose rollback/retry on failure. Use a server version/ETag with conditional updates to detect conflicts and let the user reload or resolve them. Separate unsent edits from confirmed server state rather than retaining permanent overrides.

The app privacy manifest declares UserDefaults use within the app's own container (CA92.1), following [Apple's required-reason API guidance](https://developer.apple.com/documentation/technotes/tn3183-adding-required-reason-api-entries-to-your-privacy-manifest).
