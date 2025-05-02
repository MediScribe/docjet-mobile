FIRST ORDER OF BUSINESS:
**READ THIS FIRST, MOTHERFUCKER, AND CONFIRM:** [hard-bob-workflow.mdc](../../../.cursor/rules/hard-bob-workflow.mdc)

# TODO: Implement General Transient Notification System

**Goal:** Replace the auth-specific `TransientErrorBanner` and its state management in `AuthNotifier` with a generic, application-wide system for displaying transient messages (info, success, warning, error) triggered from anywhere, decoupling non-auth notifications from the authentication domain.

**Commit plan:**
- Add feature-general-notifier.md with architecture, cycles, tasks
- Define mandatory reporting rules for each cycle
- Use single-message approach for MVP (simpler, no queue)
- Include unique ID for each message to support equality checks
- Support flexible duration configuration per message type
- Ensure proper cleanup in Riverpod with AutoDispose

---

## Target Flow / Architecture

1.  **`AppMessage` Data Class:** Define `AppMessage(String id, String message, MessageType type, Duration? duration)` where `MessageType` is an enum (`info`, `success`, `warning`, `error`). The `id` should be a unique identifier (UUID or timestamp).
2.  **`NotificationService` (Riverpod Notifier):**
    *   Located likely in `lib/core/common/notifiers/` or `lib/core/services/`.
    *   Manages `StateNotifier<AppMessage?>`.
    *   Provides methods: `show(String message, MessageType type, [Duration? duration])` and `dismiss()`.
    *   Includes auto-dismiss `Timer` logic (cancel previous timer on new message).
    *   Uses `AutoDispose` + `Ref.onDispose` to prevent timer leaks.
3.  **`ConfigurableTransientBanner` Widget:**
    *   Located in `lib/core/common/widgets/`.
    *   Takes `AppMessage` and `onDismiss` callback.
    *   Uses `MessageType` to determine background color (via `AppColorTokens`) and potentially an icon.
    *   Reuses animation/layout from the old `TransientErrorBanner`. **DRY**.
    *   Adds `Semantics(liveRegion: true, ...)` for accessibility.
4.  **Integration:**
    *   `AppShell` listens to `notificationServiceProvider` and displays `ConfigurableTransientBanner`.
    *   `AuthNotifier` *injects* `NotificationService`. Calls `notificationService.show(..., MessageType.error)` instead of setting its internal `transientError` state.
5.  **Cleanup:**
    *   Remove `transientError` from `AuthState`.
    *   Remove `clearTransientError()` from `AuthNotifier`.
    *   Delete the old `TransientErrorBanner` widget (`lib/core/common/widgets/transient_error_banner.dart`).
    *   Delete `TransientError` data class (`lib/core/auth/transient_error.dart`).
    *   Update ADR and `docs/current/start.md` to reference this change.

---

**MANDATORY REPORTING RULE:** For **every** task/cycle below, **before check-off and moving on to the next todo**, the dev must (a) write a brief *Findings* paragraph summarizing *what was done and observed* and (b) a *Handover Brief* summarising status, edge-cases/gotchas, and next-step readiness **inside this doc** before ticking the checkbox. No silent check-offs allowed – uncertainty gets you fucking fired. Like Mafee forgetting the shorts, don't be that guy.

---

## Cycle 1: Build the Core Notification Service & Widget

**MANDATORY REPORTING RULE:** After *each sub-task* below and *before* ticking its checkbox, you **MUST** add a **Findings** note *and* a **Handover Brief**. No silent check-offs. Uncertainty will get you fucking fired.

* 1.1. [ ] **Task:** Define `AppMessage` class and `MessageType` enum.
    * Implementation File: [e.g., `lib/core/common/models/app_message.dart`]
    * Findings:
* 1.2. [ ] **Task:** Implement `NotificationService` (Riverpod Notifier) with state management and methods:
    * `show(String message, MessageType type, [Duration? duration])`
    * `dismiss()`
    * Include auto-dismiss timer (cancel previous timer on new message) **and ensure it's cancelled in `dispose()`.**
    * Implementation File: [e.g., `lib/core/common/notifiers/notification_service.dart`]
    * Test File: [e.g., `test/core/common/notifiers/notification_service_test.dart`]
    * Findings:
* 1.3. [ ] **Tests RED:** Write tests for `NotificationService` (state changes on show/dismiss, timer behavior using `fakeAsync` from `clock.dart`).
    * Findings:
* 1.3.1. [ ] **Tests RED:** Verify that a second `show()` call replaces the current message and resets the timer (single-message policy).
    * Findings:
* 1.4. [ ] **Implement GREEN:** Ensure `NotificationService` passes tests.
    * Findings:
* 1.5. [ ] **Task:** Implement `ConfigurableTransientBanner` widget, using `AppMessage` and `MessageType` for styling (colors from `AppColorTokens`, Material icons). Reuse layout/animation from old `TransientErrorBanner` but use `Curves.easeOutCubic` for smoother animation **and add `Semantics` for a11y**.
    * Implementation File: [e.g., `lib/core/common/widgets/configurable_transient_banner.dart`]
    * Findings:
* 1.6. [ ] **Task:** Create a basic test/playground page to visually verify `ConfigurableTransientBanner` appearance for all `MessageType`s.
    * Findings:
* 1.6.2. [ ] **Task:** Create golden tests for `ConfigurableTransientBanner`, one per `MessageType` to capture visual regression.
    * Implementation File: [e.g., `test/core/common/widgets/configurable_transient_banner_test.dart`]
    * Findings:
* 1.7. [ ] **Refactor:** Clean up service and widget code.
    * Findings:
* 1.8. [ ] **Run Cycle-Specific Tests:**
    * Command: `./scripts/list_failed_tests.dart test/core/common/notifiers/notification_service_test.dart --except`
    * Findings:
* 1.9. [ ] **Format, Analyze, and Fix:**
    * Command: `./scripts/fix_format_analyze.sh`
    * Findings:
* 1.10. [ ] **Handover Brief:**
    * Status: Core notification service and reusable banner widget implemented and tested. Ready for integration.
    * Gotchas:
    * Recommendations: Proceed to Cycle 2.

---

## Cycle 2: Integrate Service, Refactor Auth, Cleanup

**MANDATORY REPORTING RULE:** After *each sub-task* below and *before* ticking its checkbox, you **MUST** add a **Findings** note *and* a **Handover Brief**. No silent check-offs. Uncertainty will get you fucking fired.

* 2.1. [ ] **Task:** Integrate `ConfigurableTransientBanner` into `AppShell`, listening to `notificationServiceProvider`.
    * Implementation File: `lib/core/auth/presentation/widgets/app_shell.dart`
    * Findings:
* 2.2. [ ] **Task:** Inject `NotificationService` into `AuthNotifier` (via constructor or service locator).
    * Implementation File: `lib/core/auth/presentation/auth_notifier.dart`
    * Findings:
* 2.3. [ ] **Task:** Refactor `AuthNotifier`: Replace internal `transientError` setting logic with calls to `notificationService.show(..., MessageType.error)` **and write an integration/unit test to confirm the notifier is called when a profile 404 occurs**.
    * Implementation File: `lib/core/auth/presentation/auth_notifier.dart`
    * Test File: `test/core/auth/presentation/auth_notifier_test.dart` (verify mocks)
    * Findings:
* 2.4. [ ] **Tests RED/GREEN:** Update `AuthNotifier` tests to mock `NotificationService` and verify it's called correctly instead of checking `transientError` state.
    * Findings:
* 2.5. [ ] **Task:** Remove `transientError` field from `AuthState`. Update `copyWith`, `props`, constructors.
    * Implementation File: `lib/core/auth/presentation/auth_state.dart`
    * Findings:
* 2.5.2. [ ] **Task:** Update E2E tests that rely on `transientError` state (e.g., `test/e2e/auth_flow_test.dart`).
    * Implementation File: `test/e2e/auth_flow_test.dart` and any other affected E2E tests.
    * Findings:
* 2.6. [ ] **Task:** Remove `clearTransientError` method from `AuthNotifier`.
    * Implementation File: `lib/core/auth/presentation/auth_notifier.dart`
    * Findings:
* 2.7. [ ] **Task:** Delete `TransientError` class file.
    * File: `lib/core/auth/transient_error.dart`
    * Findings:
* 2.8. [ ] **Task:** Delete `TransientErrorBanner` widget file.
    * File: `lib/core/common/widgets/transient_error_banner.dart`
    * Findings:
* 2.9. [ ] **Refactor:** Address any fallout from removals/changes **including cleaning up doc references (`architecture-overview.md`, etc.)**.
    * Findings:
* 2.10. [ ] **Run ALL Unit/Integration Tests:**
    * Command: `./scripts/list_failed_tests.dart --except`
    * Findings: `[Confirm ALL unit/integration tests pass. FIX if not.]`
* 2.11. [ ] **Format, Analyze, and Fix:**
    * Command: `./scripts/fix_format_analyze.sh`
    * Findings: `[Confirm ALL formatting and analysis issues are fixed. FIX if not.]`
* 2.12. [ ] **Run ALL E2E & Stability Tests:**
    * Command: `./scripts/run_all_tests.sh`
    * Findings: `[Confirm ALL tests pass, including E2E and stability checks. FIX if not.]`
* 2.13. [ ] **Handover Brief:**
    * Status: General notification system integrated, `AuthNotifier` refactored, old error banner system removed.
    * Gotchas:
    * Recommendations: Ready for final polish/docs.

---

## Cycle 3: Final Polish, Documentation & Cleanup

**MANDATORY REPORTING RULE:** After *each sub-task* below and *before* ticking its checkbox, you **MUST** add a **Findings** note *and* a **Handover Brief**. No silent check-offs. Uncertainty will get you fucking fired.

* 3.1. [ ] **Task:** Update relevant architecture diagrams/docs (e.g., `architecture-overview.md`, potentially new doc for notifications). **Add a paragraph capturing the single-message vs queue decision.**
    * File: [e.g., `docs/current/architecture-overview.md`]
    * Findings:
* 3.2. [ ] **Task:** Review code for any remaining dead code or cleanup opportunities.
    * Findings:
* 3.3. [ ] **Run ALL Unit/Integration Tests:**
    * Command: `./scripts/list_failed_tests.dart --except`
    * Findings: `[Confirm ALL unit/integration tests pass. FIX if not.]`
* 3.4. [ ] **Format, Analyze, and Fix:**
    * Command: `./scripts/fix_format_analyze.sh`
    * Findings: `[Confirm ALL formatting and analysis issues are fixed. FIX if not.]`
* 3.5. [ ] **Run ALL E2E & Stability Tests:**
    * Command: `./scripts/run_all_tests.sh`
    * Findings: `[Confirm ALL tests pass, including E2E and stability checks. FIX if not.]`
* 3.6. [ ] **Manual Smoke Test:** Trigger info/success/warning/error messages from various points (if applicable/easy) and check banner appearance/dismissal.
    * Findings:
* 3.7. [ ] **Code Review & Commit Prep:**
    * Findings:
* 3.8. [ ] **Handover Brief:**
    * Status: General notifier complete, tested, documented, ready for commit.
    * Gotchas:
    * Recommendations: Merge it.

---

## DONE

With these cycles we:
1. Implemented a general-purpose transient notification service (`NotificationService`).
2. Created a reusable, configurable banner widget (`ConfigurableTransientBanner`).
3. Refactored `AuthNotifier` to use the new service for displaying transient auth errors.
4. Removed the old auth-specific error banner system (`TransientError`, `TransientErrorBanner`).

No bullshit, no uncertainty – "Like Michael Prince buying up the competition, we consolidated." 