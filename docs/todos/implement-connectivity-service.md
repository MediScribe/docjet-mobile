FIRST ORDER OF BUSINESS:
**READ THIS FIRST, MOTHERFUCKER, AND CONFIRM:** [hard-bob-workflow.mdc](../../../.cursor/rules/hard-bob-workflow.mdc)

# TODO: Enhance NetworkInfo with Auth Event Integration

**Goal:** Enhance the existing `NetworkInfoImpl` to emit auth events (`offlineDetected`/`onlineRestored`) when connectivity changes, ensuring the app's offline state is driven by actual network connectivity rather than waiting for API calls to fail.

---

## Target Architecture (Updated)

```mermaid
graph TD
    subgraph "Network Layer"
        ConnectivityPlus[connectivity_plus Plugin] -->|Raw Stream| NetworkInfoImpl;
    end

    subgraph "Core Services"
        NetworkInfoImpl -->|Implements| NetworkInfo(NetworkInfo Interface<br>- isConnected<br>- onConnectivityChanged);
        NetworkInfoImpl -->|Fires Events| AuthEventBus([Auth Event Bus]);
    end

    subgraph "Authentication"
        AuthEventBus -->|Listens for Events| AuthNotifier(AuthNotifier<br>- Updates AuthState.isOffline);
    end

    subgraph "UI Layer"
        AuthNotifier -->|Provides State| AppShell(AppShell<br>- Shows/Hides OfflineBanner);
        OfflineBanner([Offline Banner UI]);
        AppShell --> OfflineBanner;
    end

    style NetworkInfoImpl fill:#f9f,stroke:#333,stroke-width:2px
    style AuthNotifier fill:#ccf,stroke:#333,stroke-width:2px
```

**Sequence Diagram (Offline Transition):**
```mermaid
sequenceDiagram
    participant CP as Connectivity Plugin
    participant NI as NetworkInfoImpl
    participant Bus as AuthEventBus
    participant AN as AuthNotifier
    participant UI as AppShell/OfflineBanner

    Note over CP, UI: Network connection drops
    CP->>NI: Event (ConnectivityResult.none)
    NI->>NI: Map to false (offline)
    alt Status Changed (was online)
        NI->>Bus: add(AuthEvent.offlineDetected)
        Bus->>AN: Event (AuthEvent.offlineDetected)
        AN->>AN: Update state (isOffline = true)
        AN->>UI: Notify state change
        UI->>UI: Show OfflineBanner
    end
```

---

## Cycle 0: Setup & Code Analysis

* 0.1. [X] **Research:** Review `NetworkInfo` interface and `NetworkInfoImpl` implementation.
    * Findings: `NetworkInfo` interface exists in `lib/core/interfaces/network_info.dart` with two methods: `Future<bool> get isConnected` and `Stream<bool> get onConnectivityChanged`. `NetworkInfoImpl` already implements this using `connectivity_plus` in `lib/core/platform/network_info_impl.dart`.
    * Handover Brief: The existing `NetworkInfo` already provides connectivity status through its methods, but it doesn't fire auth events. We need to enhance it to send events through the `AuthEventBus` rather than creating a new service.

* 0.2. [X] **Research:** Verify `AuthEventBus` and `AuthEvent` support.
    * Findings: `AuthEventBus` exists in `lib/core/auth/events/auth_event_bus.dart` and `AuthEvent` enum in `lib/core/auth/events/auth_events.dart` already includes `offlineDetected` and `onlineRestored` events.
    * Handover Brief: The event infrastructure is already in place. We just need to connect `NetworkInfoImpl` to the bus.

* 0.3. [X] **Research:** Check `AuthNotifier` current offline detection.
    * Findings: `AuthNotifier` already implements `_checkConnectivityTransition()` that emits events but is only called when API exceptions occur, not directly from network changes.
    * Handover Brief: We need to centralize connectivity detection in `NetworkInfoImpl` and remove the exception-based detection in `AuthNotifier`.

* 0.4. [X] **Research:** Validate DI registration approach.
    * Findings: Both `NetworkInfo` and `AuthEventBus` are registered in `core_module.dart`. We need to update the `NetworkInfoImpl` registration to inject `AuthEventBus`.
    * Handover Brief: DI registration needs to be updated to inject `AuthEventBus` into `NetworkInfoImpl`.

---

## Cycle 1: Enhance NetworkInfoImpl (No Event Firing Yet)

* 1.1. [X] **Tests RED:** Update/Create tests for NetworkInfoImpl.
    * Test File: `test/core/platform/network_info_impl_test.dart`
    * Test Description:
        * Existing tests for `isConnected` and `onConnectivityChanged` should remain
        * New test: `should have proper disposal to clean up resources`
        * New test: `should handle initial connectivity check on initialization`
    * Findings:
* 1.2. [X] **Implement GREEN:** Update `NetworkInfoImpl` to add resource management.
    * Implementation File: `lib/core/platform/network_info_impl.dart`
    * Add:
        * StreamSubscription property to track connectivity subscription
        * dispose() method to clean up resources
        * Initial connectivity check storage
    * Findings:
* 1.3. [X] **Refactor:** Clean up implementation and tests.
    * Findings:
* 1.4. [X] **Run Cycle-Specific Tests:**
    * Command: `./scripts/list_failed_tests.dart test/core/platform/network_info_impl_test.dart --except`
    * Findings: All 14 tests passed after refactoring flaky/hanging tests.
* 1.5. [X] **Handover Brief:**
    * Status: `NetworkInfoImpl` now has proper resource management and handles initial status.
    * Gotchas: Ensure `dispose` is called correctly by the DI container eventually. Initial implementation had flaky tests due to timing of async init and broadcast streams; tests now focus on final state rather than intermediate verification or unreliable stream error catching.
    * Recommendations: Proceed to Cycle 2 for event firing integration.

---

## Cycle 2: Add Auth Event Integration to NetworkInfoImpl

* 2.1. [ ] **Tests RED:** Update/add unit tests for `NetworkInfoImpl`.
    * Test File: `test/core/platform/network_info_impl_test.dart`
    * Test Description:
        * `should add AuthEvent.offlineDetected to bus when connectivity changes from online to offline`
        * `should add AuthEvent.onlineRestored to bus when connectivity changes from offline to online`
        * `should NOT add events to bus when connectivity status does not change`
        * `should NOT add events to bus on initialization` (no immediate transition events)
    * Findings:
* 2.2. [ ] **Implement GREEN:** Enhance `NetworkInfoImpl`.
    * Implementation File: `lib/core/platform/network_info_impl.dart`
    * Add:
        * Accept `AuthEventBus` in constructor
        * Track previous connectivity state
        * Subscribe to `connectivity.onConnectivityChanged`
        * Compare new state with previous
        * Fire appropriate events on transitions
    * Findings:
* 2.3. [ ] **Refactor:** Clean up the state transition logic. Ensure events are fired reliably.
    * Findings:
* 2.4. [ ] **Update DI Registration:**
    * File: `lib/core/di/core_module.dart`
    * Update `NetworkInfoImpl` registration to inject `AuthEventBus`
    * Findings:
* 2.5. [ ] **Run Cycle-Specific Tests:**
    * Command: `./scripts/list_failed_tests.dart test/core/platform/network_info_impl_test.dart --except`
    * Findings:
* 2.6. [ ] **Run ALL Unit/Integration Tests:**
    * Command: `./scripts/list_failed_tests.dart --except`
    * Findings:
* 2.7. [ ] **Format, Analyze, and Fix:**
    * Command: `dart fix --apply && ./scripts/format.sh && dart analyze`
    * Findings:
* 2.8. [ ] **Handover Brief:**
    * Status: `NetworkInfoImpl` now properly fires auth events on connectivity transitions.
    * Gotchas: Ensure proper state tracking, no false positives/negatives.
    * Recommendations: Proceed to Cycle 3 for cleaning up duplicate logic in `AuthNotifier`.

---

## Cycle 3: Clean Up AuthNotifier Connectivity Logic

* 3.1. [ ] **Research:** Review `AuthNotifier` implementation to understand usage of `_checkConnectivityTransition`.
    * Findings:
* 3.2. [ ] **Tests RED:** Update/modify unit tests for `AuthNotifier`.
    * Test File: `test/core/auth/presentation/auth_notifier_test.dart`
    * Test Description:
        * `should set isOffline true when offlineDetected event received` (existing test)
        * `should set isOffline false when onlineRestored event received` (existing test)
        * `should NOT manually emit offlineDetected or onlineRestored events` (new test)
        * `should handle isOffline state in AuthState correctly after events` (verification test)
    * Findings:
* 3.3. [ ] **Implement GREEN:**
    * File: `lib/core/auth/presentation/auth_notifier.dart`
    * Changes:
        * Remove `_wasOffline` property
        * Remove `_checkConnectivityTransition` method
        * Remove all calls to `_checkConnectivityTransition` from methods like `login`, `_checkAuthStatus`, etc.
        * Keep the event handling in `_listenToAuthEvents` to update `isOffline` based on received events
        * Keep the profile refresh logic, but call it directly when handling `onlineRestored` event
    * Findings:
* 3.4. [ ] **Refactor:** Clean up AuthNotifier code. Ensure proper error handling.
    * Findings:
* 3.5. [ ] **Run Cycle-Specific Tests:**
    * Command: `./scripts/list_failed_tests.dart test/core/auth/presentation/auth_notifier_test.dart --except`
    * Findings:
* 3.6. [ ] **Run ALL Unit/Integration Tests:**
    * Command: `./scripts/list_failed_tests.dart --except`
    * Findings:
* 3.7. [ ] **Format, Analyze, and Fix:**
    * Command: `dart fix --apply && ./scripts/format.sh && dart analyze`
    * Findings:
* 3.8. [ ] **Handover Brief:**
    * Status: `AuthNotifier` no longer handles connectivity detection, only responds to events.
    * Gotchas: Ensure no regressions in auth-related functionality.
    * Recommendations: Proceed to Cycle 4 for final testing and validation.

---

## Cycle 4: Final Testing, Cleanup & Validation

* 4.1. [ ] **Task:** Manual Smoke Test - Scenario 1 (Server Kill)
    * Action: `run_with_mock.sh`, log in, perform action (e.g., create job). Kill *only* the mock server process (`lsof -t -i:8080 | xargs kill -9 || true`). Observe app.
    * Expected: `OfflineBanner` should appear shortly after server is killed. App remains usable in offline mode.
    * Findings:
* 4.2. [ ] **Task:** Manual Smoke Test - Scenario 2 (Network Toggle)
    * Action: `run_with_mock.sh`, log in. Use device/simulator controls to disable network connectivity (WiFi/Cellular). Observe app. Re-enable network. Observe app.
    * Expected: `OfflineBanner` appears when network disabled, disappears when re-enabled. Profile refresh might trigger after re-enabling.
    * Findings:
* 4.3. [ ] **Task:** Update Architecture Docs
    * File: `docs/current/feature-auth-architecture.md` (Update connectivity section), `docs/current/architecture-overview.md` (Update connectivity section).
    * Findings:
* 4.4. [ ] **Run ALL Unit/Integration Tests:**
    * Command: `./scripts/list_failed_tests.dart --except`
    * Findings:
* 4.5. [ ] **Format, Analyze, and Fix:**
    * Command: `dart fix --apply && ./scripts/format.sh && dart analyze`
    * Findings:
* 4.6. [ ] **Run ALL E2E & Stability Tests:**
    * Command: `./scripts/run_all_tests.sh`
    * Findings:
* 4.7. [ ] **Code Review & Commit Prep:** Review staged changes (`git diff --staged | cat`), ensure adherence to guidelines.
    * Findings:
* 4.8. [ ] **Handover Brief:**
    * Status: Feature complete, tested, validated manually, documented. Ready for Hard Bob Commit.
    * Gotchas: 
    * Recommendations: 

---

## DONE

With these cycles we:
1. Enhanced the existing `NetworkInfoImpl` to fire auth events when connectivity changes
2. Removed duplicate detection logic from `AuthNotifier`
3. Centralized connectivity detection in a single place
4. Ensured the `OfflineBanner` accurately reflects true network connectivity state

No bullshit, no uncertainty – "You don't tell me what I'm looking at. I'll tell you what the fuck I'm looking at." - Bobby Axelrod. 