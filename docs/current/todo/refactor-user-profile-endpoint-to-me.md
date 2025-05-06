FIRST ORDER OF BUSINESS:
**READ THIS FIRST, MOTHERFUCKER, AND CONFIRM:** [hard-bob-workflow.mdc](../../../.cursor/rules/hard-bob-workflow.mdc)

# TODO: Refactor User Profile Endpoint to `/api/v1/users/me`

**Goal:** Replace the hacked `/users/<userId>` and deprecated `/users/profile` endpoint for fetching user profiles with the new, correct `/api/v1/users/me` endpoint. This will simplify the codebase, remove technical debt, and align with the actual backend API, ensuring we're not "renting space to uncertainty."

---

## Target Flow / Architecture (Optional but Recommended)

**Current (Simplified):**
```mermaid
sequenceDiagram
    participant UserApiClient
    participant ProfileEndpointWorkaround
    participant ApiConfig
    participant Dio
    participant MockServerOld

    UserApiClient->>_resolveProfileEndpoint(): Needs path
    _resolveProfileEndpoint()->>ApiConfig: Get userProfileEndpoint (e.g., 'users/profile')
    ApiConfig-->>_resolveProfileEndpoint(): 'users/profile'
    _resolveProfileEndpoint()->>ProfileEndpointWorkaround: transformProfileEndpoint('users/profile', creds)
    ProfileEndpointWorkaround-->>_resolveProfileEndpoint(): 'users/<userId>' (hacked path)
    UserApiClient->>Dio: GET 'users/<userId>'
    Dio->>MockServerOld: GET /api/v1/users/<userId> OR /api/v1/users/profile
    MockServerOld-->>Dio: UserProfile
    Dio-->>UserApiClient: UserProfile
```

**Target:**
```mermaid
sequenceDiagram
    participant UserApiClient
    participant ApiConfig
    participant Dio
    participant MockServerNew

    UserApiClient->>_resolveProfileEndpoint(): Needs path
    _resolveProfileEndpoint()->>ApiConfig: Get userProfileEndpoint (now 'users/me')
    ApiConfig-->>_resolveProfileEndpoint(): 'users/me'
    UserApiClient->>Dio: GET 'users/me'
    Dio->>MockServerNew: GET /api/v1/users/me
    MockServerNew-->>Dio: UserProfile
    Dio-->>UserApiClient: UserProfile
```

---

**MANDATORY REPORTING RULE:** For **every** task/cycle below, **before check-off and moving on to the next todo**, the dev must (a) write a brief *Findings* paragraph summarizing *what was done and observed* and (b) a *Handover Brief* summarising status at the end of the cycle, edge-cases/gotchas, and next-step readiness **inside this doc** before ticking the checkbox. No silent check-offs allowed – uncertainty gets you fucking fired. Like Mafee forgetting the shorts, don't be that guy.

---

## Cycle 0: Investigation & Plan Confirmation

**Goal** Confirm understanding of the current clusterfuck, verify the proposed solution is sound, and ensure all affected areas are identified. No blindfolded demolition work.

**MANDATORY REPORTING RULE:** After *each sub-task* below and *before* ticking its checkbox, you **MUST** add a **Findings** note *and* a **Handover Brief**.

* 0.1. [x] **Task:** Review existing `UserApiClient`, `ProfileEndpointWorkaround`, and `ApiConfig` to understand current profile fetching logic and the hack.
    * Action: Code review of specified files.
    * Findings: Current logic uses `ProfileEndpointWorkaround` to change `ApiConfig.userProfileEndpoint` (currently 'users/profile') to 'users/<userId>'. The workaround is self-contained and ripe for deletion. `UserApiClient._resolveProfileEndpoint()` is the key method to simplify.
* 0.2. [x] **Task:** Analyze `mock_api_server/bin/server.dart` and `mock_api_server/test/user_test.dart` for old endpoint handlers and tests.
    * Action: Code review of mock server files.
    * Findings: Mock server has handlers for `/users/profile` and `/users/<userId>`. Tests exist for both. These need to be removed and replaced.
* 0.3. [x] **Task:** Grep codebase for all usages of "users/profile" and "users/" with a user ID pattern to identify all files that might need updates (client code, tests, documentation).
    * Action: `default_api.grep_search(query="/users/")`
    * Findings: Numerous references found across client code, mock server, tests, and documentation. Key files already identified, but a final sweep will be needed during documentation updates.
* 0.4. [x] **Task:** Confirm the new endpoint structure: `GET /api/v1/users/me` returning `{"id": "...", "email": "...", ...}`.
    * Action: User confirmation.
    * Findings: Confirmed.
* 0.5. [x] **Update Plan:** Review the multi-cycle plan based on these findings.
    * Action: Review the proposed plan (Cycle 1: Mock Server, Cycle 2: Client-Side, Cycle 3: Cleanup & Docs).
    * Findings: [Plan confirmed and refined based on detailed code review. Key areas for attention include ensuring the mock server's new `/users/me` endpoint correctly mirrors the auth requirements (API Key + Bearer Token) and response structure of the old `/users/profile` endpoint, and that tests for deprecated endpoints are updated to expect 404s or are removed.]
* 0.6. [x] **Handover Brief:**
    * Status: [Investigation complete. The battle plan is solid, verified against current code. We know the enemy, its name is `ProfileEndpointWorkaround`, and its days are numbered.]
    * Gotchas: [The `ApiPathMatcher` might be an orphaned child after this; we'll need to check its parentage or send it to an orphanage. Ensure mock server's new `/users/me` correctly implements auth and response consistent with the old `/users/profile`.]
    * Recommendations: [Proceed with Cycle 1: Mock Server Overhaul. Prepare for righteous deletion. Pay close attention to mock server auth logic and test updates for old endpoints.]

---

## Cycle 1: Mock Server Overhaul

**Goal** Gut the mock server of its old, shitty user profile endpoints and install the new, pristine `/api/v1/users/me` handler. Tests first, no cowboy shit.

**MANDATORY REPORTING RULE:** After *each sub-task* below and *before* ticking its checkbox, you **MUST** add a **Findings** note *and* a **Handover Brief** at the end of the cycle.

* 1.1. [x] **Research:** Review existing mock server auth middleware and response structures to ensure the new `/api/v1/users/me` endpoint integrates cleanly.
    * Findings: [The mock server applies a global `_authMiddleware` that checks for a valid `X-API-Key` on all routes except health and debug. The old `/users/profile` endpoint handler (`_getUserProfileHandler`) additionally performed its own JWT Bearer token validation (`Authorization: Bearer <token>`) and extracted the user ID from the token's `sub` claim. The old `/users/<userId>` handler relied only on the global API key check. Therefore, the new `/api/v1/users/me` handler must also perform its own JWT Bearer token validation (like `/users/profile` did) and will automatically be covered by the global API key check. The response structure of `/users/profile` (`{"id": "...", "name": "...", "email": "...", "settings": {...}}`) should be mirrored, with the `id` derived from the JWT `sub` claim.]
* 1.2. [x] **Tests RED:**
    * Test File: `mock_api_server/test/user_test.dart`
    * Test Description:
        *   Add new tests for `GET /api/v1/users/me`:
            *   Success case (200 with correct profile data, checking headers).
            *   Failure case (401 if auth headers missing/invalid).
        *   Modify existing tests for `/api/v1/users/profile` and `/api/v1/users/<userId>`:
            *   Ensure they now expect 404s (as handlers will be deleted). Tests for handlers that are completely removed should themselves be removed to avoid clutter.
    * Run the tests: `./scripts/list_failed_tests.dart mock_api_server/test/user_test.dart --except`
    * Findings: [Tests executed. 10 out of 17 tests failed as expected. New tests for `/api/v1/users/me` predominantly fail with 404 (Not Found) instead of 200 (OK) or specific 401s (Unauthorized), as the endpoint and its logic do not yet exist. Modified tests for deprecated `/users/<userId>` and `/users/profile` also fail, as they currently hit existing handlers (returning 200s or 401s) instead of the target 404s. This confirms the RED state: the tests demand changes that are not yet implemented.]
* 1.3. [x] **Implement GREEN:**
    * Implementation File: `mock_api_server/bin/server.dart`
    * Action:
        *   Remove the route handlers for `/$_versionedApiPath/users/profile`.
        *   Remove the route handler for `/$_versionedApiPath/users/<userId>`.
        *   Add a new route handler `..get('/$_versionedApiPath/users/me', _getUserMeHandler)`.
        *   Implement `_getUserMeHandler` to:
            *   Perform auth checks: strictly enforce both API key (`X-API-Key`) and Bearer token (`Authorization: Bearer <token>`), reusing logic from the old `/users/profile` handler if possible.
            *   Return a 200 OK with the user profile JSON: `{"id": "mock-user-id-from-token-sub-claim", "email": "user@example.com", "full_name": "Mock User", ...}`. (Extract user ID from token's 'sub' claim like the old profile handler did). Ensure the response structure is identical to the one previously returned by `/users/profile`.
    * Findings: [Code implemented in `mock_api_server/bin/server.dart`. The old route declarations for `/users/profile` and `/users/<userId>` were removed. A new route `GET /users/me` was added, pointing to a new `_getUserMeHandler`. This handler implements JWT Bearer token authentication (checking for valid token and non-empty `sub` claim) and returns user data in the same structure as the old `/users/profile` endpoint. The global API key middleware continues to provide X-API-Key protection. Upon re-running tests (`./scripts/list_failed_tests.dart mock_api_server/test/user_test.dart --except`), all 17 tests now pass. The mock server correctly serves `/api/v1/users/me` and rejects calls to the old endpoints with 404s as intended.]
* 1.4. [x] **Refactor:** Clean up `mock_api_server/bin/server.dart` and `mock_api_server/test/user_test.dart`. Remove any dead code and tests related to the old endpoints.
    * Findings: [Removed reference to the old handlers in the comments in `mock_api_server/bin/server.dart`. Discovered and fixed 4 failing tests in `mock_api_server/test/auth_test.dart` that still expected responses from the removed `/users/profile` endpoint. Updated those tests to expect 404 Not Found responses (except for the API key missing case which still returns 401 from the middleware). After these changes, all tests in the `mock_api_server` package pass, confirming our successful refactoring.]
* 1.5. [x] **Run Cycle-Specific Tests:**
    * Command: `./scripts/list_failed_tests.dart mock_api_server/test/user_test.dart`
    * Findings: [All 17 tests in `user_test.dart` pass. New tests for `/users/me` verify correct authentication logic and response structure. Tests for removed endpoints correctly verify they return 404s now.]
* 1.6. [x] **Run ALL Unit/Integration Tests (Mock Server):**
    * Command: `./scripts/list_failed_tests.dart mock_api_server`
    * Findings: [All 104 tests in the mock server pass after our changes, including the previously failing tests in `auth_test.dart`. This confirms we've handled all dependencies and edge cases correctly.]
* 1.7. [x] **Format, Analyze, and Fix (Mock Server):**
    * Command: `cd mock_api_server && dart format . && dart analyze`
    * Findings: [No formatting or analysis issues detected. The code is clean and compliant with style guidelines.]
* 1.8. [x] **Handover Brief:**
    * Status: [Mock server has been successfully purged of the old filth and now proudly serves `/api/v1/users/me`. Tests confirm its newfound purity. The `/users/profile` and `/users/<userId>` endpoints are gone, only returning 404s now. All tests have been updated to reflect this change, including those in `auth_test.dart` which we discovered were still expecting the old behavior.]
    * Gotchas: [Discovered that endpoint changes need to be reflected in ALL test files, not just the primary ones. The `auth_test.dart` file had tests for the deprecated endpoint that needed updates. Be aware of cross-dependencies between tests and functionality. Also remember that auth middleware runs before routing, so some 401 responses still happen even for non-existent routes.]
    * Recommendations: [Proceed to Cycle 2: Client-Side Refactoring. The mock server is ready, but the client is still trying to call endpoints that no longer exist. Now we need to update `ApiConfig` to use the new endpoint and remove the `ProfileEndpointWorkaround` hack.]

---

## Cycle 2: Client-Side Exorcism

**Goal** Rip out the `ProfileEndpointWorkaround` demon from the client, update `ApiConfig`, and point `UserApiClient` to the one true path: `/api/v1/users/me`.

**MANDATORY REPORTING RULE:** After *each sub-task* below and *before* ticking its checkbox, you **MUST** add a **Findings** note *and* a **Handover Brief** at the end of the cycle.

* 2.1. [x] **Research:** Review `test/core/user/infrastructure/user_api_client_test.dart`. Understand how it currently mocks dependencies and verifies calls, especially concerning the transformed endpoint.
    * Findings: [Tests currently mock `authenticatedDio.get()` with the *hacked* path `users/<userId>`, which is derived by mocking `AuthCredentialsProvider.getUserId()` and `AuthCredentialsProvider.getAccessToken()` (for JWT decoding by the workaround). The tests explicitly verify that this transformed path is called. This will need to change to expect `users/me` (the raw value from `ApiConfig.userProfileEndpoint`) and the JWT decoding mock for path construction will become obsolete for this part of the test.]
* 2.2. [x] **Tests RED:**
    * Test File: `test/core/user/infrastructure/user_api_client_test.dart`
    * Test Description: Modify existing tests for `UserApiClient.getUserProfile()`. They should now:
        *   Expect `ApiConfig.userProfileEndpoint` to be called (which will soon be `users/me`).
        *   No longer need to mock or account for `ProfileEndpointWorkaround` or JWT decoding for path construction.
        *   These tests should fail because `ApiConfig` and `UserApiClient` are still on the old system.
    * Run the tests: `./scripts/list_failed_tests.dart test/core/user/infrastructure/user_api_client_test.dart --except`
    * Findings: [Test `UserApiClient getUserProfile should use authenticatedDio` fails as expected. The test now stubs `authenticatedDio.get('users/profile')` (current `ApiConfig.userProfileEndpoint`) but the actual call is to `authenticatedDio.get('users/user-123')` due to the active `ProfileEndpointWorkaround` and mocked user ID. This confirms the RED state: the client code needs to change to align with the test's new expectation of using `ApiConfig.userProfileEndpoint` directly.]
* 2.3. [x] **Implement GREEN:**
    * Files:
        *   `lib/core/config/api_config.dart`
        *   `lib/core/user/infrastructure/user_api_client.dart`
        *   `lib/core/user/infrastructure/hack_profile_endpoint_workaround.dart` (for deletion)
    * Action:
        1.  In `lib/core/config/api_config.dart`:
            *   Changed `static const String userProfileEndpoint = 'users/profile';`
            *   To `static const String userProfileEndpoint = 'users/me';`
        2.  In `lib/core/user/infrastructure/user_api_client.dart`:
            *   In `_resolveProfileEndpoint()`, deleted the call to `ProfileEndpointWorkaround.transformProfileEndpoint(...)`.
            *   Set it to `return ApiConfig.userProfileEndpoint;` (now returns 'users/me').
            *   Removed `HACK-TODO` comments and the import for `hack_profile_endpoint_workaround.dart`.
        3.  Deleted `lib/core/user/infrastructure/hack_profile_endpoint_workaround.dart`.
    * Findings: [Client code updated as planned. `ApiConfig.userProfileEndpoint` is now 'users/me'. `UserApiClient._resolveProfileEndpoint` now directly returns this value. The `hack_profile_endpoint_workaround.dart` file has been deleted. Re-running `user_api_client_test.dart` confirms all tests pass. GREEN achieved.]
* 2.4. [x] **Refactor:** Clean up `UserApiClient` and its tests. Ensure clarity and remove any lingering HACK comments related to the old endpoint.
    * Findings: [Updated doc comment for `_resolveProfileEndpoint()` in `user_api_client.dart` to accurately reflect its new, simpler behavior. Removed an outdated `HACK-TODO` comment from `user_api_client_test.dart`. Removed the unnecessary mock for `credentialsProvider.getUserId()` from the `setUp` block in `user_api_client_test.dart`, as it was only required by the deleted workaround. All tests remain green. Client code is now as clean and direct as a sniper shot.]
* 2.5. [x] **Run Cycle-Specific Tests:**
    * Command: `./scripts/list_failed_tests.dart test/core/user/infrastructure/user_api_client_test.dart --except`
    * Findings: [All 4 tests in `user_api_client_test.dart` pass. The `UserApiClient` correctly interacts with the new `users/me` endpoint configuration and its tests are clean and focused.]
* 2.6. [x] **Run ALL Unit/Integration Tests:**
    * Command: `./scripts/list_failed_tests.dart --except`
    * Findings: [All 843 unit/integration tests pass. The client-side changes to use `/api/v1/users/me` and the removal of `ProfileEndpointWorkaround` have not introduced any regressions. The force is strong with this one.]
* 2.7. [x] **Format, Analyze, and Fix:**
    * Command: `./scripts/fix_format_analyze.sh`
    * Findings: [The `./scripts/fix_format_analyze.sh` script completed successfully. `dart fix` found nothing to fix, `dart format` reported 0 changed files, and `dart analyze` found no issues. The codebase is clean and adheres to all linting and formatting rules.]
* 2.8. [x] **Run ALL E2E & Stability Tests:**
    * Command: `./scripts/run_all_tests.sh`
    * Findings: [The `./scripts/run_all_tests.sh` script completed successfully. All unit tests (843), mock server tests (105), and E2E tests passed. App stability checks also passed. The new user profile endpoint integration is solid and has not introduced any user-facing regressions.]
* 2.9. [x] **Handover Brief:**
    * Status: [Client-side hack has been exorcised. `UserApiClient` now correctly calls the new `/api/v1/users/me` endpoint via `ApiConfig`. All unit, integration, E2E, and stability tests pass, confirming the change is robust. The mock server is aligned from Cycle 1.]
    * Gotchas: [Ensure any manual QA or non-standard E2E test setups that might have hardcoded mock responses for old profile endpoints (`/users/profile`, `/users/<userId>`) are updated. The primary E2E suite (`run_all_tests.sh`) is confirmed green.]
    * Recommendations: [Proceed to Cycle 3: Final Cleanup & Documentation. Key tasks will be to review `ApiPathMatcher` for obsolescence/updates, ensure all documentation reflects the `/api/v1/users/me` endpoint, and conduct a final code review. Sweep the leg, Johnny.]

---

## Cycle 3: Final Cleanup, Documentation & Verification

**Goal** Eradicate any remaining traces of the old endpoints, update all documentation to reflect the new reality, and perform a final verification. Leave no stone unturned, no bullshit unaddressed.

**MANDATORY REPORTING RULE:** After *each sub-task* below and *before* ticking its checkbox, you **MUST** add a **Findings** note *and* a **Handover Brief** at the end of the cycle.

* 3.1. [ ] **Task:** Review and Update `lib/core/auth/utils/api_path_matcher.dart`.
    * Action:
        *   Check if `ApiPathMatcher.isUserProfile()` is still used anywhere in the codebase (post Cycle 2 changes) using grep.
        *   If used: Update its regex `_profileRegex` to match `users/me` (e.g., `RegExp(r'\/users\/me(\/?(\?.*)?)?$');`). Update its tests in `test/core/auth/utils/api_path_matcher_test.dart`.
        *   If NOT used: Delete `ApiPathMatcher.isUserProfile()` and its tests. If the class becomes empty, consider deleting the file.
    * Findings: [Document whether it was updated or deleted, and confirm related tests pass or are removed.]
* 3.2. [ ] **Task:** Update All Project Documentation.
    * Files: Systematically go through documentation files identified in Cycle 0 grep results, plus key architectural docs:
        *   `docs/current/feature-auth-architecture.md`
        *   `docs/current/start.md`
        *   `docs/current/setup-mock-server.md` (if it mentions specific user endpoints)
        *   `mock_api_server/README.md`
        *   Any other files referencing `/users/profile` or `/users/<userId>` for fetching the current user's profile.
    * Action: Replace all relevant mentions of the old user profile endpoints with `/api/v1/users/me`. Ensure diagrams and descriptions are accurate.
    * Findings: [All documentation updated to reflect the new `/api/v1/users/me` endpoint. Consistency achieved.]
* 3.3. [ ] **Run ALL Unit/Integration Tests:**
    * Command: `./scripts/list_failed_tests.dart --except`
    * Findings: `[Confirm ALL unit/integration tests pass. FIX if not.]`
* 3.4. [ ] **Format, Analyze, and Fix:**
    * Command: `./scripts/fix_format_analyze.sh`
    * Findings: `[Confirm ALL formatting and analysis issues are fixed. FIX if not.]`
* 3.5. [ ] **Run ALL E2E & Stability Tests:**
    * Command: `./scripts/run_all_tests.sh`
    * Findings: `[Confirm ALL tests pass, including E2E and stability checks. FIX if not.]`
* 3.6. [ ] **Manual Smoke Test:** (If applicable and feasible with mock or staging)
    * Action: Launch app, log in, navigate to areas that display user information (e.g., profile screen if one exists, or any UI element showing user's email/name).
    * Findings: [User information is fetched and displayed correctly using the new endpoint.]
* 3.7. [ ] **Code Review & Commit Prep:**
    * Action: Review all staged changes (`git diff --staged | cat`). Ensure adherence to Hard Bob principles: DRY, SOLID, CLEAN. No commented-out bullshit, no lingering TODOs related to this refactor.
    * Findings: [Code is immaculate. Changes are focused and correct. Ready for a Hard Bob Commit that would make Axe proud.]
* 3.8. [ ] **Handover Brief:**
    * Status: [The refactor is complete. Old endpoints are gone. New `/api/v1/users/me` endpoint is integrated across mock server and client. Documentation is updated. All tests pass.]
    * Gotchas: [None. We stared into the abyss of the hack, and the hack blinked first.]
    * Recommendations: [This is ready for a Hard Bob Commit. Ship it. "The new king is dead. Long live the king!"]

---

## DONE

With these cycles we:
1. Eradicated the shitty `/users/profile` and `/users/<userId>` hack from the mock server and client.
2. Seamlessly integrated the new, proper `/api/v1/users/me` endpoint for fetching user profiles.
3. Updated all relevant tests and documentation, leaving a codebase cleaner than a Cistercian monastery.

No bullshit, no uncertainty – "Certainty. That's what I'm selling."