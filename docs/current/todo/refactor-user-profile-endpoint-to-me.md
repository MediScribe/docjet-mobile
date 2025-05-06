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
* 0.5. [ ] **Update Plan:** Review the multi-cycle plan based on these findings.
    * Action: Review the proposed plan (Cycle 1: Mock Server, Cycle 2: Client-Side, Cycle 3: Cleanup & Docs).
    * Findings: [Plan confirmed and refined based on detailed code review. Key areas for attention include ensuring the mock server's new `/users/me` endpoint correctly mirrors the auth requirements (API Key + Bearer Token) and response structure of the old `/users/profile` endpoint, and that tests for deprecated endpoints are updated to expect 404s or are removed.]
* 0.6. [ ] **Handover Brief:**
    * Status: [Investigation complete. The battle plan is solid, verified against current code. We know the enemy, its name is `ProfileEndpointWorkaround`, and its days are numbered.]
    * Gotchas: [The `ApiPathMatcher` might be an orphaned child after this; we'll need to check its parentage or send it to an orphanage. Ensure mock server's new `/users/me` correctly implements auth and response consistent with the old `/users/profile`.]
    * Recommendations: [Proceed with Cycle 1: Mock Server Overhaul. Prepare for righteous deletion. Pay close attention to mock server auth logic and test updates for old endpoints.]

---

## Cycle 1: Mock Server Overhaul

**Goal** Gut the mock server of its old, shitty user profile endpoints and install the new, pristine `/api/v1/users/me` handler. Tests first, no cowboy shit.

**MANDATORY REPORTING RULE:** After *each sub-task* below and *before* ticking its checkbox, you **MUST** add a **Findings** note *and* a **Handover Brief** at the end of the cycle.

* 1.1. [ ] **Research:** Review existing mock server auth middleware and response structures to ensure the new `/api/v1/users/me` endpoint integrates cleanly.
    * Findings: [e.g., Auth middleware checks for `X-API-Key` and `Authorization: Bearer <token>`. New endpoint should follow this. Standard JSON response structure. Confirm `/users/profile` required both API key and Bearer token; `/users/me` must do the same.]
* 1.2. [ ] **Tests RED:**
    * Test File: `mock_api_server/test/user_test.dart`
    * Test Description:
        *   Add new tests for `GET /api/v1/users/me`:
            *   Success case (200 with correct profile data, checking headers).
            *   Failure case (401 if auth headers missing/invalid).
        *   Modify existing tests for `/api/v1/users/profile` and `/api/v1/users/<userId>`:
            *   Ensure they now expect 404s (as handlers will be deleted). Tests for handlers that are completely removed should themselves be removed to avoid clutter.
    * Run the tests: `cd mock_api_server && dart test test/user_test.dart` (or relevant script)
    * Findings: [New tests for `/users/me` fail as expected (no handler). Tests for old endpoints pass if not modified, or fail if modified to expect 404s against existing handlers (these will be removed/updated in green stage).]
* 1.3. [ ] **Implement GREEN:**
    * Implementation File: `mock_api_server/bin/server.dart`
    * Action:
        *   Remove the route handlers for `/$_versionedApiPath/users/profile`.
        *   Remove the route handler for `/$_versionedApiPath/users/<userId>`.
        *   Add a new route handler `..get('/$_versionedApiPath/users/me', _getUserMeHandler)`.
        *   Implement `_getUserMeHandler` to:
            *   Perform auth checks: strictly enforce both API key (`X-API-Key`) and Bearer token (`Authorization: Bearer <token>`), reusing logic from the old `/users/profile` handler if possible.
            *   Return a 200 OK with the user profile JSON: `{"id": "mock-user-id-from-token-sub-claim", "email": "user@example.com", "full_name": "Mock User", ...}`. (Extract user ID from token's 'sub' claim like the old profile handler did). Ensure the response structure is identical to the one previously returned by `/users/profile`.
    * Findings: [Code implemented. New tests for `/users/me` should now pass. Tests for old endpoints should fail (as handlers are gone) or be deleted.]
* 1.4. [ ] **Refactor:** Clean up `mock_api_server/bin/server.dart` and `mock_api_server/test/user_test.dart`. Remove any dead code and tests related to the old endpoints.
    * Findings: [Code and tests are cleaner than a germaphobe's operating room.]
* 1.5. [ ] **Run Cycle-Specific Tests:**
    * Command: `cd mock_api_server && dart test test/user_test.dart`
    * Findings: [All tests in `user_test.dart` pass. The mock server is behaving like a well-trained attack dog.]
* 1.6. [ ] **Run ALL Unit/Integration Tests (Mock Server):**
    * Command: `cd mock_api_server && dart test`
    * Findings: `[Confirm ALL mock server tests pass. FIX if not.]`
* 1.7. [ ] **Format, Analyze, and Fix (Mock Server):**
    * Command: `cd mock_api_server && dart format . && dart analyze`
    * Findings: `[Confirm ALL formatting and analysis issues are fixed. FIX if not.]`
* 1.8. [ ] **Handover Brief:**
    * Status: [Mock server has been successfully purged of the old filth and now proudly serves `/api/v1/users/me`. Tests confirm its newfound purity.]
    * Gotchas: [Ensure the new handler correctly mimics any nuances of the real backend's auth, if known (e.g., specific error messages for bad tokens). Confirm the mock `/users/me` strictly enforces both API key and Bearer token auth, consistent with the old `/users/profile`.]
    * Recommendations: [Proceed to Cycle 2: Client-Side Refactoring. The client is currently dumber than a bag of hammers, calling endpoints that no longer exist on the mock. Time to educate it.]

---

## Cycle 2: Client-Side Exorcism

**Goal** Rip out the `ProfileEndpointWorkaround` demon from the client, update `ApiConfig`, and point `UserApiClient` to the one true path: `/api/v1/users/me`.

**MANDATORY REPORTING RULE:** After *each sub-task* below and *before* ticking its checkbox, you **MUST** add a **Findings** note *and* a **Handover Brief** at the end of the cycle.

* 2.1. [ ] **Research:** Review `test/core/user/infrastructure/user_api_client_test.dart`. Understand how it currently mocks dependencies and verifies calls, especially concerning the transformed endpoint.
    * Findings: [e.g., Tests mock `authenticatedDio.get()` with the *hacked* path `users/<userId>`. This will need to change to expect `users/me` (unprefixed) or the full path depending on how `ApiConfig` is used.]
* 2.2. [ ] **Tests RED:**
    * Test File: `test/core/user/infrastructure/user_api_client_test.dart`
    * Test Description: Modify existing tests for `UserApiClient.getUserProfile()`. They should now:
        *   Expect `ApiConfig.userProfileEndpoint` to be called (which will soon be `users/me`).
        *   No longer need to mock or account for `ProfileEndpointWorkaround` or JWT decoding for path construction.
        *   These tests should fail because `ApiConfig` and `UserApiClient` are still on the old system.
    * Run the tests: `./scripts/list_failed_tests.dart test/core/user/infrastructure/user_api_client_test.dart --except`
    * Findings: [Tests fail, likely because `authenticatedDio.get()` is still being called with the old hacked path, or `ApiConfig.userProfileEndpoint` isn't updated yet, and the mocks expect the new path.]
* 2.3. [ ] **Implement GREEN:**
    * Files:
        *   `lib/core/config/api_config.dart`
        *   `lib/core/user/infrastructure/user_api_client.dart`
        *   `lib/core/user/infrastructure/hack_profile_endpoint_workaround.dart` (for deletion)
    * Action:
        1.  In `lib/core/config/api_config.dart`:
            *   Change `static const String userProfileEndpoint = 'users/profile';`
            *   To `static const String userProfileEndpoint = 'users/me';`
        2.  In `lib/core/user/infrastructure/user_api_client.dart`:
            *   In `_resolveProfileEndpoint()`, delete the entire call to `ProfileEndpointWorkaround.transformProfileEndpoint(...)`.
            *   Uncomment and use: `return ApiConfig.userProfileEndpoint;` (this will now return 'users/me').
            *   Remove the `HACK-TODO` comments.
            *   Remove the import for `hack_profile_endpoint_workaround.dart`.
        3.  Delete the file `lib/core/user/infrastructure/hack_profile_endpoint_workaround.dart`. Send it to the fucking void.
    * Findings: [Client code updated. `hack_profile_endpoint_workaround.dart` is now sleeping with the fishes. Tests in `user_api_client_test.dart` should pass.]
* 2.4. [ ] **Refactor:** Clean up `UserApiClient` and its tests. Ensure clarity and remove any lingering HACK comments related to the old endpoint.
    * Findings: [Client code is now as clean and direct as a sniper shot.]
* 2.5. [ ] **Run Cycle-Specific Tests:**
    * Command: `./scripts/list_failed_tests.dart test/core/user/infrastructure/user_api_client_test.dart --except`
    * Findings: [All tests for `UserApiClient` pass. It knows the new truth.]
* 2.6. [ ] **Run ALL Unit/Integration Tests:**
    * Command: `./scripts/list_failed_tests.dart --except`
    * Findings: `[Confirm ALL unit/integration tests pass. FIX if not. Pay attention to any tests that might have relied on the old profile fetching behavior indirectly.]`
* 2.7. [ ] **Format, Analyze, and Fix:**
    * Command: `./scripts/fix_format_analyze.sh`
    * Findings: `[Confirm ALL formatting and analysis issues are fixed. FIX if not.]`
* 2.8. [ ] **Run ALL E2E & Stability Tests:**
    * Command: `./scripts/run_all_tests.sh`
    * Findings: `[Confirm ALL tests pass, including E2E and stability checks. This is crucial as profile fetching is fundamental. FIX if not.]`
* 2.9. [ ] **Handover Brief:**
    * Status: [Client-side hack has been exorcised. `UserApiClient` now correctly calls the new `/api/v1/users/me` endpoint via `ApiConfig`. All relevant client tests pass.]
    * Gotchas: [Double-check E2E tests if any explicitly set up mock responses for the old profile endpoints; they might need adjustment.]
    * Recommendations: [Proceed to Cycle 3: Final Cleanup & Documentation. Sweep the leg, Johnny.]

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