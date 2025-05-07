FIRST ORDER OF BUSINESS:
**READ THIS FIRST, MOTHERFUCKER, AND CONFIRM:** [hard-bob-workflow.mdc](../../../.cursor/rules/hard-bob-workflow.mdc)

# TODO: Refactor `mock_api_server/bin/server.dart` into Modules

**Goal:** Systematically decompose the monolithic `mock_api_server/bin/server.dart` into organized, single-responsibility modules (handlers, core, middleware, routes) to unfuck its current state, enhance clarity, and make it testable. We're not building a house of cards; we're building a fucking fortress, one solid brick at a time.

---

## Guiding Principles for Refactoring

1.  **Export Strategy & Naming**:
    *   When moving functions (e.g., handlers, utils) to new files, make them part of the file's public API by removing any leading underscores from their names (e.g., `_myFunction` becomes `myFunction`).
    *   Each new `.dart` file in `src/` should be treated as a module. Consider using `library` and `export` directives if fine-grained control over exported symbols is needed, though for this refactor, simply making functions top-level and public (no underscore) in their respective files should suffice. The goal is clear, intentional exposure of functionality.
    *   Ensure `api_router.dart` and `server.dart` (and any other consumers) import these public functions correctly from their new locations.
2.  **Testing is Non-Negotiable**: After any code movement or significant change within a cycle, and after `dart analyze` passes, the full test suite **MUST** be run using `./scripts/list_failed_tests.dart mock_api_server --debug | cat`. A clean bill of health from the tests is mandatory before proceeding. We're not flying blind.

---

## Target Flow / Architecture (Optional but Recommended)

**Initial State:** `mock_api_server/bin/server.dart` ( monolithic monster ~900 lines)

**Target State:**
```
mock_api_server/
├── bin/
│   └── server.dart         # Main entry point, pipeline setup
├── src/
│   ├── core/
│   │   ├── constants.dart    # API versions, keys, durations
│   │   └── utils.dart        # Helper functions (e.g., readAsString)
│   ├── handlers/
│   │   ├── auth_handlers.dart
│   │   ├── job_handlers.dart
│   │   ├── health_handlers.dart
│   │   └── debug_handlers.dart # (Already exists, confirm its location/integration)
│   ├── middleware/
│   │   └── middleware.dart   # _authMiddleware, _debugMiddleware
│   ├── routes/
│   │   └── api_router.dart     # Router setup, imports handlers
│   └── job_store.dart      # (Already exists, confirm its location/integration)
│   └── config.dart         # (Already exists, confirm its location/integration)
└── ... (pubspec.yaml, etc.)
```

---

**MANDATORY REPORTING RULE:** For **every** task/cycle below, **before check-off and moving on to the next todo**, the dev must (a) write a brief *Findings* paragraph summarizing *what was done and observed* (this includes results from `dart analyze` and test runs) and (b) a *Handover Brief* summarising status at the end of the cycle, edge-cases/gotchas, and next-step readiness **inside this doc** before ticking the checkbox. No silent check-offs allowed – uncertainty gets you fucking fired. Like Mafee forgetting the shorts, don't be that guy.

---

## Cycle 0: Setup & Directory Structure

**Goal:** Establish the foundational directory structure for the refactored server. No code moves yet, just setting the fucking stage.

**MANDATORY REPORTING RULE:** After *each sub-task* below and *before* ticking its checkbox, you **MUST** add a **Findings** note *and* a **Handover Brief**. No silent check-offs. Uncertainty will get you fucking fired.

* 0.1. [x] **Task:** Verify/Create `mock_api_server/src/` directory.
    * Action: `ls mock_api_server/src || mkdir -p mock_api_server/src`
    * Findings: Command executed. Directory `mock_api_server/src` was created as it did not exist.
* 0.2. [x] **Task:** Create `mock_api_server/src/core/` directory.
    * Action: `mkdir -p mock_api_server/src/core`
    * Findings: Command executed. Directory `mock_api_server/src/core` created.
* 0.3. [x] **Task:** Create `mock_api_server/src/handlers/` directory.
    * Action: `mkdir -p mock_api_server/src/handlers`
    * Findings: Command executed. Directory `mock_api_server/src/handlers` created.
* 0.4. [x] **Task:** Create `mock_api_server/src/middleware/` directory.
    * Action: `mkdir -p mock_api_server/src/middleware`
    * Findings: Command executed. Directory `mock_api_server/src/middleware` created.
* 0.5. [x] **Task:** Create `mock_api_server/src/routes/` directory.
    * Action: `mkdir -p mock_api_server/src/routes`
    * Findings: Command executed. Directory `mock_api_server/src/routes` created.
* 0.6. [x] **Update Plan:**
    * Findings: Directory structure for core, handlers, middleware, and routes established within `mock_api_server/src/`. No other files currently exist at `mock_api_server/src/` root. Plan is solid.
* 0.7. [x] **Handover Brief:**
    * Status: Base directories (`core`, `handlers`, `middleware`, `routes`) created within `mock_api_server/src/`. No pre-existing files were found at the root of `mock_api_server/src/`. Ready for Cycle 1.
    * Gotchas: None for this cycle.
    * Recommendations: Proceed to Cycle 1: Core Component Extraction.

---

## Cycle 1: Extract Core Constants & Utilities

**Goal:** Isolate shared constants and utility functions into their own modules within `src/core/`. This is the low-hanging fruit, an easy fucking win.

**MANDATORY REPORTING RULE:** After *each sub-task* below and *before* ticking its checkbox, you **MUST** add a **Findings** note *and* a **Handover Brief** at the end of the cycle. No silent check-offs. Uncertainty will get you fucking fired.

* 1.1. [x] **Task:** Create and populate `mock_api_server/src/core/constants.dart`.
    * Action: Move global constants (`_apiVersion`, `_apiPrefix`, `_versionedApiPath`, `_expectedApiKey`, `_mockJwtSecret`, `_accessTokenDuration`, `_refreshTokenDuration`) from `server.dart` to `constants.dart`. Ensure necessary imports (e.g., `package:uuid/uuid.dart` for `_uuid` if moved here, though `utils.dart` is better).
    * Findings: Created `mock_api_server/src/core/constants.dart` and moved `apiVersion`, `apiPrefix`, `versionedApiPath`, `expectedApiKey`, `mockJwtSecret`, `accessTokenDuration`, and `refreshTokenDuration` into it, making them public (removed leading underscores). The `_uuid` constant was intentionally left in `server.dart` for now, to be handled in task 1.2. Attempts to remove the original constant definitions from `mock_api_server/bin/server.dart` via automated edits failed repeatedly; these definitions currently remain (commented out by a previous faulty edit attempt) in `server.dart` and will need to be addressed manually or in a subsequent step (likely when imports are added in 1.3, which will cause conflicts if they are not removed).
* 1.2. [x] **Task:** Create and populate `mock_api_server/src/core/utils.dart`.
    * Action: Move `readAsString` function and `_uuid` instance from `server.dart` to `utils.dart`. Add necessary imports (e.g., `dart:async`, `dart:convert`, `package:uuid/uuid.dart`).
    * Findings: Created `mock_api_server/src/core/utils.dart` and moved the `readAsString` function and `uuid` instance (formerly `_uuid`) into it, making them public. Necessary imports (`dart:async`, `dart:convert`, `package:uuid/uuid.dart`) were added to `utils.dart`. Similar to task 1.1, attempts to remove the original definitions from `mock_api_server/bin/server.dart` resulted in them being commented out instead of deleted. These commented-out definitions remain in `server.dart`.
* 1.3. [x] **Task:** Update `server.dart` imports for new `constants.dart` and `utils.dart`.
    * Action: Add `import '../src/core/constants.dart';` and `import '../src/core/utils.dart';` (or correct relative paths) to `server.dart`. Remove the original definitions.
    * Findings: Added imports for `../src/core/constants.dart` and `../src/core/utils.dart` to `mock_api_server/bin/server.dart`. The original constant and utility definitions (which were previously commented out) were successfully removed. References to these constants/utils within `server.dart` were updated to use their new public names (e.g., `_versionedApiPath` became `versionedApiPath`). An initial issue with the import path for `config.dart` (incorrectly changed to relative) was corrected back to `package:mock_api_server/src/config.dart`. An erroneously added call to `job_store.initializeJobStore` in `main()` was also removed.
* 1.4. [x] **Task:** Run `dart analyze` on `mock_api_server/`.
    * Action: `./scripts/fix_format_analyze.sh | cat`
    * Findings: Script executed. `dart fix` applied 1 fix (unused_import) in `mock_api_server/bin/server.dart`. Formatter made no changes. `dart analyze` reported 3 warnings in `test/core/auth/infrastructure/` mocks, which are outside the scope of `mock_api_server` and this refactoring cycle. No issues reported within `mock_api_server/`.
* 1.4.1. [x] **Task:** Run tests.
    * Action: `./scripts/list_failed_tests.dart mock_api_server --debug | cat`
    * Findings: Initial run: 75/105 tests failed due to `Connection refused`. Investigation revealed `mock_api_server/bin/server.dart` was ignoring the `--port` command-line argument from `test_helpers.dart` and defaulting to port 8080. Fix: Modified `server.dart` to prioritize the parsed `--port` argument. Second run: All 105 tests passed.
* 1.5. [ ] **Handover Brief:**
    * Status: Constants (`constants.dart`) and utilities (`utils.dart`) successfully extracted from `server.dart` into `mock_api_server/src/core/`. `server.dart` has been updated to import and use these new modules. The `fix_format_analyze.sh` script runs clean for `mock_api_server/`. All 105 tests in `mock_api_server` are passing after resolving an issue with port handling in `server.dart`.
    * Gotchas: The `server.dart` was not respecting the `--port` argument passed by test infrastructure, causing initial widespread test failures. This was fixed by ensuring `server.dart` uses the parsed command-line port. The `dart fix` command also removed an unused `package:uuid/uuid.dart` import from `server.dart`, which was correct after refactoring.
    * Recommendations: Proceed to Cycle 2: Middleware Extraction.

---

## Cycle 2: Extract Middleware

**Goal:** Relocate `_debugMiddleware` and `_authMiddleware` to `mock_api_server/src/middleware/middleware.dart`.

**MANDATORY REPORTING RULE:** ...

* 2.1. [ ] **Task:** Create and populate `mock_api_server/src/middleware/middleware.dart`.
    * Action: Move `_debugMiddleware` and `_authMiddleware` functions from `server.dart` to `middleware.dart`. Add necessary imports (e.g., `package:shelf/shelf.dart`, `dart:convert`, `../core/constants.dart`, `../config.dart`).
    * Findings:
* 2.2. [ ] **Task:** Update `server.dart` imports for new `middleware.dart`.
    * Action: Add `import '../src/middleware/middleware.dart';` to `server.dart`. Remove original definitions.
    * Findings:
* 2.3. [ ] **Task:** Run `dart analyze` on `mock_api_server/`.
    * Action: `./scripts/fix_format_analyze.sh | cat`
    * Findings:
* 2.3.1. [ ] **Task:** Run tests.
    * Action: `./scripts/list_failed_tests.dart mock_api_server --debug | cat`
    * Findings:
* 2.4. [ ] **Handover Brief:**
    * Status: Middleware extracted. `server.dart` imports updated. Analyzer clean. All tests passing.
    * Gotchas:
    * Recommendations: Proceed to Cycle 3: Router Extraction.

---

## Cycle 3: Extract Router Logic

**Goal:** Move the `_router` definition and its route configurations to `mock_api_server/src/routes/api_router.dart`.

**MANDATORY REPORTING RULE:** ...

* 3.1. [ ] **Task:** Create and populate `mock_api_server/src/routes/api_router.dart`.
    * Action: Move `_router` instance and its route definitions from `server.dart` to `api_router.dart`. This file will need to import all handler functions.
    * Findings:
* 3.2. [ ] **Task:** Update `server.dart` to import and use the new `api_router.dart`.
    * Action: Add `import '../src/routes/api_router.dart';` and use the router from there in the pipeline.
    * Findings:
* 3.3. [ ] **Task:** Run `dart analyze` on `mock_api_server/`.
    * Action: `./scripts/fix_format_analyze.sh | cat`
    * Findings:
* 3.3.1. [ ] **Task:** Run tests.
    * Action: `./scripts/list_failed_tests.dart mock_api_server --debug | cat`
    * Findings:
* 3.4. [ ] **Handover Brief:**
    * Status: Router logic extracted. `server.dart` imports updated. Analyzer clean. All tests passing.
    * Gotchas: This is a critical step. Double-check all handler imports in `api_router.dart`.
    * Recommendations: Proceed to Cycle 4: Handler Extraction (Health & Auth).

---

## Cycle 4: Extract Health & Auth Handlers

**Goal:** Move `_healthHandler`, `_loginHandler`, `_refreshHandler`, and `_getUserMeHandler` into their respective files in `src/handlers/`.

**MANDATORY REPORTING RULE:** ...

* 4.1. [ ] **Task:** Create `mock_api_server/src/handlers/health_handlers.dart` and move `_healthHandler`.
    * Action: Move `_healthHandler`. Add imports (e.g., `package:shelf/shelf.dart`). Update `api_router.dart` to import from here.
    * Findings:
* 4.2. [ ] **Task:** Create `mock_api_server/src/handlers/auth_handlers.dart` and move `_loginHandler`, `_refreshHandler`, `_getUserMeHandler`.
    * Action: Move handlers. Add imports (e.g., `dart:convert`, `package:shelf/shelf.dart`, `package:dart_jsonwebtoken/dart_jsonwebtoken.dart`, `../../core/constants.dart`, `../../config.dart`). Update `api_router.dart`.
    * Findings:
* 4.3. [ ] **Task:** Run `dart analyze` on `mock_api_server/`.
    * Action: `./scripts/fix_format_analyze.sh | cat`
    * Findings:
* 4.3.1. [ ] **Task:** Run tests.
    * Action: `./scripts/list_failed_tests.dart mock_api_server --debug | cat`
    * Findings:
* 4.4. [ ] **Handover Brief:**
    * Status: Health and Auth handlers extracted. Router and `server.dart` updated. Analyzer clean. All tests passing.
    * Gotchas:
    * Recommendations: Proceed to Cycle 5: Job Handler Extraction.

---

## Cycle 5: Extract Job Handlers

**Goal:** Move all job-related handlers (`_createJobHandler`, `_listJobsHandler`, `_getJobByIdHandler`, `_getJobDocumentsHandler`, `_updateJobHandler`, `_deleteJobHandler`) to `mock_api_server/src/handlers/job_handlers.dart`.

**MANDATORY REPORTING RULE:** ...

* 5.1. [ ] **Task:** Create `mock_api_server/src/handlers/job_handlers.dart` and move all job handlers.
    * Action: Move handlers. Add necessary imports (e.g., `dart:convert`, `dart:io`, `package:shelf/shelf.dart`, `package:shelf_multipart/shelf_multipart.dart`, `../../core/constants.dart`, `../../core/utils.dart`, `../../job_store.dart` (as job_store), `../../config.dart`, `../debug_handlers.dart` for `cancelProgressionTimerForJob`). Update `api_router.dart`.
    * Findings:
* 5.2. [ ] **Task:** Run `dart analyze` on `mock_api_server/`.
    * Action: `./scripts/fix_format_analyze.sh | cat`
    * Findings:
* 5.2.1. [ ] **Task:** Run tests.
    * Action: `./scripts/list_failed_tests.dart mock_api_server --debug | cat`
    * Findings:
* 5.3. [ ] **Handover Brief:**
    * Status: Job handlers extracted. Router and `server.dart` updated. Analyzer clean. All tests passing.
    * Gotchas: Pay attention to imports for `job_store` and `debug_handlers` from within `job_handlers.dart`.
    * Recommendations: Proceed to Cycle 6: Final `server.dart` Cleanup.

---

## Cycle 6: Final `server.dart` Cleanup & Verification

**Goal:** Ensure `mock_api_server/bin/server.dart` is lean, primarily containing `main()` and the server pipeline setup, importing all other components. Verify all functionality.

**MANDATORY REPORTING RULE:** ...

* 6.1. [ ] **Task:** Review `server.dart` for any remaining logic that should be moved.
    * Action: Ensure only `main`, `Pipeline` setup, signal handlers, and necessary top-level imports remain.
    * Findings:
* 6.2. [ ] **Task:** Run `dart analyze` on `mock_api_server/`.
    * Action: `./scripts/fix_format_analyze.sh | cat`
    * Findings:
* 6.3. [ ] **Task:** [IF TESTS EXIST] Run all tests.
    * Action: `(cd mock_api_server && dart test) | cat` (or equivalent test script)
    * Findings:
* 6.4. [ ] **Task:** Manual verification (if applicable, e.g., start server, hit a few endpoints).
    * Action: `dart run mock_api_server/bin/server.dart -v` then test with curl or Postman.
    * Findings:
* 6.5. [ ] **Handover Brief:**
    * Status: `server.dart` is now a clean entry point. All components modularized. Analyzer clean. All tests passing.
    * Gotchas:
    * Recommendations: Consider adding integration tests for the entire server setup if not already present.

---

## Cycle N: Final Polish, Documentation & Cleanup

**Goal:** Ensure all new files are well-documented, imports are clean, and project structure is pristine.

**MANDATORY REPORTING RULE:** ...

* N.1. [ ] **Task:** Add file-level comments (purpose of each new file).
    * Action: Add `/// ...` comments to top of each new `.dart` file.
    * Findings:
* N.2. [ ] **Task:** Review all imports for absolute vs. relative paths, unused imports.
    * Action: Clean up imports in all modified/new files.
    * Findings:
* N.3. [ ] **Task:** Run `dart format .` within `mock_api_server/`.
    * Action: `./scripts/fix_format_analyze.sh | cat`
    * Findings:
* N.4. [ ] **Task:** Run `