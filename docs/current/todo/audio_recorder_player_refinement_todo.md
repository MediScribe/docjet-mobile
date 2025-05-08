FIRST ORDER OF BUSINESS:
**READ THIS FIRST, MOTHERFUCKER, AND CONFIRM:** [hard-bob-workflow.mdc](../../../.cursor/rules/hard-bob-workflow.mdc)

# TODO: Audio Recorder & Player UI/Theming Refinement

**Goal:** Squash every god-damn inconsistency uncovered in the code-review: clean up `AppColorTokens` bloat/duplication, harden accessibility & theming of recorder/player widgets, enforce proper tests, gate dev-only screens, and lock-in missing dev-deps. No half-assed fixes – we ship polished, test-covered audio UX that would make Dollar Bill cream his pants.

---

## Target Flow / Architecture (Recommended ‑ READ IT!)

```mermaid
sequenceDiagram
    participant UI as RecorderModal
    participant AudioCubit as AudioCubit
    participant Theme as AppColorTokens
    UI->>AudioCubit: startRecording/pause/resume/stop
    UI->>Theme: getAppColors(context)
    AudioCubit-->>UI: state updates (recording, paused, loaded, playing)
    UI-->>UI: show context-aware buttons & bg colors
    Note right of UI: Tests ensure each phase renders correct controls
```

By end-game, every state transition above is visually & semantically correct, colour-consistent, and **fully tested**. No surprises.

---

**MANDATORY REPORTING RULE:** For **every** task/cycle below, **before check-off** the dev must add **Findings** + **Handover Brief** paragraphs. Skip that and you're renting space to uncertainty – and we don't do that shit.

---

## Cycle 0: Baseline & Dependency Housekeeping

**Goal** Make sure the tool-chain can actually build & test the new code.

**MANDATORY REPORTING RULE:** After *each sub-task* below and *before* ticking its checkbox, you **MUST** add a **Findings** note *and* a **Handover Brief**. No silent check-offs. Uncertainty will get you fucking fired.

**APPLY MODEL ATTENTION**: The apply model is a bit tricky to work with! For large files, edits can take up to 20s; so you might need to double check if you don't get an affirmative answer right away. Go in smaller edits.

* 0.1. [x] **Task:** Check/Add `mockito` to `dev_dependencies` in `pubspec.yaml`
    * Action: `flutter pub add --dev mockito` if not already in there.
    * Findings: `mockito` was present in `dependencies` instead of `dev_dependencies`. Moved it to `dev_dependencies`.
    * Handover Brief: `mockito` is now correctly listed under `dev_dependencies` in `pubspec.yaml`.
* 0.2. [x] **Task:** Run `dart pub outdated` & `./scripts/fix_format_analyze.sh`
    * Action: Update any wildly outdated test-only deps that break.
    * Findings: `dart pub outdated` showed several outdated dependencies, including a major version jump for `flutter_secure_storage` (4.2.1 to 9.2.4). However, `./scripts/fix_format_analyze.sh` completed without errors. No dependencies were updated at this stage.
    * Handover Brief: `fix_format_analyze.sh` passed. Outdated dependencies noted but not updated as they are not currently breaking anything.
* 0.3. [x] **Update Plan:** Adjust future cycles if analyzer screams about newly added null-safety issues.
    * Findings: The analyzer (`./scripts/fix_format_analyze.sh`) reported no issues. No null-safety issues were encountered.
    * Handover Brief: No adjustments to future cycles are needed as the analyzer is clean.
* 0.4. [x] **Handover Brief:** Baseline ready; analyzer passes; mockito installed.

---

## Cycle 1: AppColorTokens Cleanup

**Goal** Remove duplication, add missing fields, ensure copyWith/lerp/equality stay in sync.

**MANDATORY REPORTING RULE:** For **every** task/cycle below, **before check-off** the dev must add **Findings** + **Handover Brief** paragraphs. Skip that and you're renting space to uncertainty – and we don't do that shit.

**APPLY MODEL ATTENTION**: The apply model is a bit tricky to work with! For large files, edits can take up to 20s; so you might need to double check if you don't get an affirmative answer right away. Go in smaller edits.

* 1.1. [ ] **Research:** Grep for `primaryActionBg` & `primaryActionFg` usages.
* 1.2. [ ] **Tests RED:** Create `test/core/theme/app_color_tokens_test.dart` verifying:
    * `light()` & `dark()` constructors populate **all** interactive & semantic colours.
    * `copyWith` round-trips values correctly.
* 1.3. [ ] **Implement GREEN:**
    * Delete dup constants; centralise `kBrand*` at file top only once.
    * Add missing `colorSemanticRecordForeground` in dark theme.
    * Ensure **every** new field is in `copyWith`, `lerp`, `hashCode`, `==`.
* 1.4. [ ] **Refactor:** Consider splitting token groups into private helper extensions if file > 200 LOC.
* 1.5. [ ] **Run Cycle-Specific Tests:** [Execute relevant tests for *this cycle only*. Use the *correct* script.]
    * Command: [e.g., `./scripts/list_failed_tests.dart test/core/theme/app_color_tokens_test.dart --except`]
    * Findings: [Confirm cycle-specific tests pass. List any failures and fixes if necessary.]
* 1.6. [ ] **Run ALL Unit/Integration Tests:**
    * Command: `./scripts/list_failed_tests.dart --except`
    * Findings: `[Confirm ALL unit/integration tests pass. FIX if not.]`
* 1.7. [ ] **Format, Analyze, and Fix:**
    * Command: `./scripts/fix_format_analyze.sh`
    * Findings: `[Confirm ALL formatting and analysis issues are fixed. FIX if not.]`
* 1.8. [ ] **Run ALL E2E & Stability Tests:**
    * Command: `./scripts/run_all_tests.sh`
    * Findings: `[Confirm ALL tests pass, including E2E and stability checks. FIX if not.]`
* 1.9. [ ] **Handover Brief:** Tokens spotless, tests green.

---

## Cycle 2: Widget Accessibility & Semantics Hardening

**Goal** Make `CircularActionButton`, `RecordStartButton`, and `AudioPlayerWidget` WCAG-friendly & consistent with colour tokens.

**MANDATORY REPORTING RULE:** For **every** task/cycle below, **before check-off** the dev must add **Findings** + **Handover Brief** paragraphs. Skip that and you're renting space to uncertainty – and we don't do that shit.

**APPLY MODEL ATTENTION**: The apply model is a bit tricky to work with! For large files, edits can take up to 20s; so you might need to double check if you don't get an affirmative answer right away. Go in smaller edits.

* 2.1. [ ] **Research:** Audit tap-targets & semantics with Flutter inspector.
* 2.2. [ ] **Tests RED:** Add widget tests asserting:
    * Buttons expose `Semantics(label: … , enabled: …)`
    * `CircularActionButton` disabled when `onTap == null`.
* 2.3. [ ] **Implement GREEN:**
    * Wrap InkWell with `Semantics(label: tooltip ?? 'action button', button: true)`.
    * Default min-size of 48×48; assert via `Constraints`.
    * Theme all icons (play/pause/stop) using `appColors.colorBrandPrimary`.
* 2.4. [ ] **Refactor:** DRY any duplicate padding/magic-numbers (`AppSpacing`).
* 2.5. [ ] **Run Cycle-Specific Tests:** [Execute relevant tests for *this cycle only*. Use the *correct* script.]
    * Command: [e.g., `./scripts/list_failed_tests.dart test/widgets/buttons/*_test.dart --except`]
    * Findings: [Confirm cycle-specific tests pass. List any failures and fixes if necessary.]
* 2.6. [ ] **Run ALL Unit/Integration Tests:**
    * Command: `./scripts/list_failed_tests.dart --except`
    * Findings: `[Confirm ALL unit/integration tests pass. FIX if not.]`
* 2.7. [ ] **Format, Analyze, and Fix:**
    * Command: `./scripts/fix_format_analyze.sh`
    * Findings: `[Confirm ALL formatting and analysis issues are fixed. FIX if not.]`
* 2.8. [ ] **Run ALL E2E & Stability Tests:**
    * Command: `./scripts/run_all_tests.sh`
    * Findings: `[Confirm ALL tests pass, including E2E and stability checks. FIX if not.]`
* 2.9. [ ] **Handover Brief:** Buttons ADA-compliant; semantics verified.

---

## Cycle 3: RecorderModal & Player Coverage

**Goal** Bullet-proof the modal & player with behavior-driven widget tests.

**MANDATORY REPORTING RULE:** For **every** task/cycle below, **before check-off** the dev must add **Findings** + **Handover Brief** paragraphs. Skip that and you're renting space to uncertainty – and we don't do that shit.

**APPLY MODEL ATTENTION**: The apply model is a bit tricky to work with! For large files, edits can take up to 20s; so you might need to double check if you don't get an affirmative answer right away. Go in smaller edits.

* 3.1. [ ] **Research:** Determine minimal mocks for `AudioCubit` state phases.
* 3.2. [ ] **Tests RED:** `test/widgets/recorder_modal_test.dart` scenarios:
    * Idle (no recording) → only RecordStartButton visible.
    * Recording → shows timer, pause + stop.
    * Paused → shows resume + stop.
    * Loaded → shows AudioPlayerWidget + accept/cancel.
* 3.3. [ ] **Implement GREEN:** Fix any layout bugs discovered (e.g. animated container height jump).
* 3.4. [ ] **Refactor:** Ensure helper methods remain private; mark as `static` where possible.
* 3.5. [ ] **Run Cycle-Specific Tests:** [Execute relevant tests for *this cycle only*. Use the *correct* script.]
    * Command: [e.g., `./scripts/list_failed_tests.dart test/widgets/recorder_modal_test.dart --except`]
    * Findings: [Confirm cycle-specific tests pass. List any failures and fixes if necessary.]
* 3.6. [ ] **Run ALL Unit/Integration Tests:**
    * Command: `./scripts/list_failed_tests.dart --except`
    * Findings: `[Confirm ALL unit/integration tests pass. FIX if not.]`
* 3.7. [ ] **Format, Analyze, and Fix:**
    * Command: `./scripts/fix_format_analyze.sh`
    * Findings: `[Confirm ALL formatting and analysis issues are fixed. FIX if not.]`
* 3.8. [ ] **Run ALL E2E & Stability Tests:**
    * Command: `./scripts/run_all_tests.sh`
    * Findings: `[Confirm ALL tests pass, including E2E and stability checks. FIX if not.]`
* 3.9. [ ] **Handover Brief:** Modal behaves exactly per spec; tests pass.

---

## Cycle 4: Dev-Only UI Gatekeeping

**Goal** Hide `JobListPlayground` behind debug flag so we don't ship toy UI.

**MANDATORY REPORTING RULE:** For **every** task/cycle below, **before check-off** the dev must add **Findings** + **Handover Brief** paragraphs. Skip that and you're renting space to uncertainty – and we don't do that shit.

**APPLY MODEL ATTENTION**: The apply model is a bit tricky to work with! For large files, edits can take up to 20s; so you might need to double check if you don't get an affirmative answer right away. Go in smaller edits.

* 4.1. [ ] **Tests RED:** Widget test asserting button absent in release (`kReleaseMode`).
* 4.2. [ ] **Implement GREEN:** Wrap button in `if (kDebugMode) … `.
* 4.3. [ ] **Refactor:** Move import behind conditional or ignore analyzer `unused_import` in release.
* 4.4. [ ] **Run Cycle-Specific Tests:** [Execute relevant tests for *this cycle only*. Use the *correct* script.]
    * Command: [e.g., `./scripts/list_failed_tests.dart test/features/home/presentation/screens/home_screen_test.dart --except`]
    * Findings: [Confirm cycle-specific tests pass. List any failures and fixes if necessary.]
* 4.5. [ ] **Run ALL Unit/Integration Tests:**
    * Command: `./scripts/list_failed_tests.dart --except`
    * Findings: `[Confirm ALL unit/integration tests pass. FIX if not.]`
* 4.6. [ ] **Format, Analyze, and Fix:**
    * Command: `./scripts/fix_format_analyze.sh`
    * Findings: `[Confirm ALL formatting and analysis issues are fixed. FIX if not.]`
* 4.7. [ ] **Run ALL E2E & Stability Tests:**
    * Command: `./scripts/run_all_tests.sh`
    * Findings: `[Confirm ALL tests pass, including E2E and stability checks. FIX if not.]`
* 4.8. [ ] **Handover Brief:** Playground hidden; production squeaky-clean.

---

## Cycle 5: Final Polish & Documentation

**Goal** Update docs, run full battery, prep commit.

**MANDATORY REPORTING RULE:** For **every** task/cycle below, **before check-off** the dev must add **Findings** + **Handover Brief** paragraphs. Skip that and you're renting space to uncertainty – and we don't do that shit.

**APPLY MODEL ATTENTION**: The apply model is a bit tricky to work with! For large files, edits can take up to 20s; so you might need to double check if you don't get an affirmative answer right away. Go in smaller edits.

* 5.1. [ ] **Task:** Update `docs/current/audio-recorder-player.md` with new theming semantics & widget hierarchy.
* 5.2. [ ] **Task:** Purge any dead code (`CircleIconButton` obsolete).
* 5.3. [ ] **Task:** Ensure license headers present on all new files.
* 5.4 → 5.5. Run full test & stability suite.
* 5.6. [ ] **Manual Smoke Test:** Record → play → accept on both iOS & Android simulators.
* 5.7. [ ] **Code Review & Commit Prep:** Follow Rule 10 & 11 of Hard Bob Workflow.
* 5.8. [ ] **Handover Brief:** Everything green, ready for a Hard Bob commit.

---

## DONE

Once all cycles are closed we will:
1. Eliminate theme dupes & token drift.
2. Deliver fully accessible, branded audio UI.
3. Seal dev-only toys behind debug flag.
4. Achieve 100% widget-phase coverage.

As Wags would say, "No one's ego survived this review – only clean code did." 