# Auth Issues TDD Plan

## Problem Summary:

Login failed initially with a misleading "Invalid email or password" error. The actual root causes identified were:
1.  Mock server returned 401 due to a missing `x-api-key` header.
2.  The missing header was caused by incorrect Dio instance injection (`basicDio` used instead of `authenticatedDio`).
3.  The request URL was malformed (e.g., `.../api/v1auth/login` instead of `.../api/v1/auth/login`).

Fixing the DI and URL issues introduced a circular dependency (`AuthApiClient` <-> `AuthInterceptor`) and broke tests.

## What We KNOW:

1.  **Root Causes Identified:** Missing API key header (DI error) and malformed URL (`ApiConfig` error).
2.  **Misleading Error:** `AuthApiClient` maps 401 on login incorrectly.
3.  **Circular Dependency:** Introduced when fixing DI.
4.  **Current State = Broken Tests:** Latest attempt to fix circular dependency (lazy `GetIt` in `AuthInterceptor`) broke tests (`dart analyze` shows 16 errors) due to outdated test setups.
5.  **URL Fix Applied:** Leading slashes added to `ApiConfig.dart` endpoints.

## What We ASSUME:

1.  `ApiConfig.dart` change fixed the URL path (needs runtime verification).
2.  Latest DI refactoring fixed the circular dependency (needs runtime verification).
3.  Mock server expects `ebu@me.com`/`asdasd` (needs verification if login fails with 401/400).

## Hard Bob TDD Plan:

### Phase 1: Get Tests GREEN

1.  **Fix Mocks (`build_runner`):**
    *   **Action:** Run `dart run build_runner build --delete-conflicting-outputs` to ensure mocks are up-to-date after `@GenerateMocks` changes.
    *   **Verification:** Check generated mock files (`*.mocks.dart`).

2.  **Fix `auth_interceptor_test.dart`:**
    *   **Objective:** Match new `AuthInterceptor` constructor (`GetIt` required, `apiClient` removed).
    *   **Action:** Ensure `MockGetIt` is generated. Instantiate `MockGetIt` in `setUp`. Update `AuthInterceptor` instantiation call (`getIt: mockGetIt`, remove `apiClient`). Stub `mockGetIt<AuthApiClient>()` -> `mockApiClient`.
    *   **Verification:** `dart analyze` on file. `dart test` on file.

3.  **Fix `dio_factory_test.dart`:**
    *   **Objective:** Match new `createAuthenticatedDio` signature (`GetIt` required, `authApiClient` removed).
    *   **Action:** Add `MockGetIt` instance. Update *all* calls to `mockDioFactory.createAuthenticatedDio(...)` (pass `getIt`, remove `authApiClient`).
    *   **Verification:** `dart analyze` on file. `dart test` on file.

4.  **Fix `auth_interceptor_refresh_test.dart` (Integration):**
    *   **Objective:** Fix `AuthInterceptor` instantiation.
    *   **Action:** Update `AuthInterceptor` instantiation to use `GetIt`. Add `GetIt` mocking/setup.
    *   **Verification:** `dart analyze` on file. `dart test` on file.

5.  **Fix `auth_module_test.dart` (If Necessary):**
    *   **Objective:** Ensure test setup/verification logic aligns with new signatures.
    *   **Action:** Review test setup (`setUp`) and verifications (e.g., `_verifyAuthenticatedDioCreation`) for `createAuthenticatedDio` signature changes.
    *   **Verification:** `dart analyze` on file. `dart test` on file.

6.  **Final Analysis & Cleanup:**
    *   **Action:** Run `dart analyze` on project. Run `./scripts/list_failed_tests.dart`. Fix any remaining errors/failures. Remove unused import in `dio_factory.dart`.
    *   **Verification:** `dart analyze` passes. `./scripts/list_failed_tests.dart` shows no failures.

### Phase 2: Verify Runtime & Fix Remaining Issues

7.  **Runtime Test:**
    *   **Action:** Run `./scripts/run_with_mock.sh`. Attempt login (`ebu@me.com`/`asdasd`). Capture Dio logs for POST request/response.
    *   **Verification:** Check logs for correct URL, `x-api-key` header, server status code, server response body.

8.  **Address Runtime Result:**
    *   **Action:** Based *only* on verified runtime logs, fix the *next* blocking issue.
        *   200 OK: Proceed to cleanup.
        *   401/400 (Bad Credentials): Check/fix mock server credentials.
        *   404/500: Fix mock server route (`mock_api_server/...`).
        *   Still 401 (Missing API Key): Re-debug DI/interceptors.
        *   Still bad URL: Re-debug `ApiConfig`/Dio.
        *   Other app error: Debug relevant app code.
    *   **Verification:** Re-run step 7 until login works or a new error appears.

9.  **Cleanup:**
    *   **Action:** Fix misleading error mapping in `AuthApiClient._handleDioException`. Address `TODO` for user ID clearing in `AuthInterceptor`. Remove temporary debug logging.
    *   **Verification:** App functionality correct. Code clean. 