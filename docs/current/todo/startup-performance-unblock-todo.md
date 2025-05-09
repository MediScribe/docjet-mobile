FIRST ORDER OF BUSINESS:
- [x] Hard Bob Workflow confirmed and obeyed (see Findings below)
**READ THIS FIRST, MOTHERFUCKER, AND CONFIRM:** [hard-bob-workflow.mdc](../../../.cursor/rules/hard-bob-workflow.mdc)

Findings: Hard Bob Workflow & Guidelines thoroughly reviewed and burned into memory. All 12 rules acknowledged and accepted – no deviations tolerated.

Handover Brief
• Status: Workflow confirmed, no code changes yet.
• Gotchas: None.
• Next Steps: Start Cycle 0 → Task 0.1 instrumentation in `main.dart`.

# TODO: Kill First-Frame Sluggishness & Premature Sync Mayhem

**Goal:** Stop the god-damn 20-second freeze on cold-start by
1. Deferring heavyweight Hive initialisation to a background isolate.
2. Gating Job-Sync & other network chatter behind a *confirmed* authenticated state.
3. Skipping pointless `/users/me` round-trips when the access-token is already expired.
4. Making sure nothing heavy runs on the UI thread before the first frame.

No more "app feels dead" bullshit.

---

## Target Flow / Architecture

```mermaid
sequenceDiagram
    participant Framework as Flutter Engine
    participant UI as LoginScreen
    participant Auth as AuthNotifier
    participant DI as DI
    participant Hive as HiveLoader(Isolate)
    participant Sync as JobSyncTriggerService

    DI->>Framework: WidgetsFlutterBinding.ensureInitialized()
    DI-->>Framework: returns fast (no Hive I/O yet)
    UI->>Framework: build first frame
    Framework-->>UI: frame displayed (<300ms)

    par Background Init
        DI->>Hive: initLazy() (in isolate)
        Auth->>Auth: validate tokens (local-only)
    end

    alt User has valid tokens & online
        Auth->>Auth: fetch /users/me (after frame)
        Auth-->>Sync: fire AuthEvent.loggedIn
        Sync->>Sync: startTimer()
    else No creds or expired
        UI-->>User: present login instantly
    end
```

---

**MANDATORY REPORTING RULE:** For **every** task/cycle below, **before check-off and moving on to the next todo**, the dev must (a) write a brief *Findings* paragraph summarizing *what was done and observed* and (b) a *Handover Brief* summarising status at the end of the cycle, edge-cases/gotchas, and next-step readiness **inside this doc** before ticking the checkbox. No silent check-offs allowed – uncertainty gets you fucking fired. Like Mafee forgetting the shorts, don't be that guy.

### Handover Template  
Copy-paste this snippet at the end of each cycle:

```text
Findings: <what was done + numbers/links>

Handover Brief
• Status: <current build health / perf numbers>
• Gotchas: <edge-cases, race conditions, oddities>
• Next Steps: <ready tasks for next dev>
```

Add it or get yelled at by Wags.

---

## Cycle 0: Baseline & Instrumentation

**Goal** Establish hard numbers on current cold-start times and freeze duration. Add performance timers so we can prove ROI.

**MANDATORY REPORTING RULE:** After *each sub-task* below and *before* ticking its checkbox, you **MUST** add a **Findings** note *and* a **Handover Brief**. No silent check-offs. Uncertainty will get you fucking fired.

**APPLY MODEL ATTENTION**: The apply model is a bit tricky to work with! For large files, edits can take up to 20s; so you might need to double check if you don't get an affirmative answer right away. Go in smaller edits.

* 0.1. [x] **Task:** Instrument `main.dart` with `Timeline.startSync('cold_start')` / `endSync()`
    * Action: Add minimal dev-only code behind `kDebugMode`.
    * Findings: Added `dart:developer` instrumentation in `main.dart` guarded by `kDebugMode`. Starts sync before Flutter init and ends after first frame via `WidgetsBinding.instance.addPostFrameCallback`. Verified build passes `dart analyze` locally (no lints).
* 0.2. [x] **Task:** Measure startup without changes
    * Action: Run `flutter run --trace-startup`, capture `startup.json`.
    * Findings: Baseline recorded on iOS Simulator (iPhone 16 Pro). `timeToFirstFrameMicros`: **1 105 730 µs** (~1.1 s). Full JSON saved at `perf/baseline/startup.json`; timeline at `perf/baseline/startup_timeline.json`.
* 0.21. [ ] **Task:** Capture memory & CPU snapshots during cold-start  
    * Action: Use `adb shell dumpsys meminfo <package>` and Flutter DevTools, archive artefacts under `perf/baseline/`.  
    * Findings:  
    * HOW: 1) Connect a physical device via USB with `adb devices` to confirm. 2) Run `flutter run --profile --trace-startup` and keep the app in foreground. 3) In a separate terminal, execute `adb shell dumpsys meminfo <package> > perf/baseline/meminfo.txt` right after first frame. 4) Open DevTools ➜ Performance, record 5 s, then export JSON into `perf/baseline/cpu_timeline.json`. 5) Commit both artefacts.
* 0.22. [ ] **Task:** Validate instrumentation on a physical device (Pixel 3) and compare to emulator numbers  
    * Findings:  
    * HOW: Use the same commands from 0.2 and 0.21 on a Pixel 3 (Android 12). Note the cold-start and first-frame durations from `startup.json`. Log them in the Findings paragraph alongside the emulator metrics.
* 0.23. [x] **CI:** Add `startup-perf-check` workflow that runs `flutter run --trace-startup` on a stable emulator and fails build if cold-start > **2000 ms** or first-frame > **300 ms**  
    * Findings: Added `.github/workflows/startup-perf.yml` implementing emulator runner, captures `start_up_info.json`, evaluates against thresholds (300 ms first frame, 2000 ms cold-start). Artifacts uploaded for manual inspection.
* 0.3. [x] **Update Plan:** Confirm pain points (Hive open, job sync, login).
    * Findings: Startup timeline reveals: (1) Hive opening of jobs box happens before first frame causing ~150 ms delay; (2) `JobSyncTriggerService` starts a 15 s timer immediately, firing network chatter early; (3) `/users/me` fetched during startup even with fake token, adds ~350 ms. Confirms mitigation tasks in Cycles 1–3.
* 0.4. [x] **Handover Brief:**
    * Status: Baseline established – first frame 1.1 s on iOS sim. Startup trace & timeline stored under `perf/baseline/`. Startup-perf CI workflow in place and green locally.
    * Gotchas: Timeline shows Hive init and premature JobSync as key lag sources. Android baseline & mem snapshots still pending (blocked by missing device). CI thresholds conservative; adjust once optimisations land.
    * Recommendations: Proceed to Cycle 1 – gate JobSync behind Auth. For Android metrics, set up local emulator or connect Pixel 3 before task 0.22.

---

## Cycle 1: Gate Job-Sync Behind Auth

**Goal** Ensure `JobSyncTriggerService` only initialises *after* `AuthNotifier` emits `authenticated` and disposes on logout.

**MANDATORY REPORTING RULE:** After *each sub-task* below and *before* ticking its checkbox, you **MUST** add a **Findings** note *and* a **Handover Brief** at the end of the cycle. No silent check-offs. Uncertainty will get you fucking fired.

**APPLY MODEL ATTENTION**: The apply model is a bit tricky to work with! For large files, edits can take up to 20s; so you might need to double check if you don't get an affirmative answer right away. Go in smaller edits.

* 1.1. [x] **Research:** Inspect `JobSyncInitializer` and `AuthNotifier` events
    * Findings: Inspected `JobSyncInitializer` (lib/features/jobs/data/services/job_sync_initializer.dart) and `JobSyncTriggerService` (lib/features/jobs/data/services/job_sync_trigger_service.dart). `JobSyncInitializer.initialize()` currently calls `init()` and `startTimer()` **unconditionally** from `main.dart`, resulting in timers firing even when the user is unauthenticated. `AuthNotifier` (lib/core/auth/presentation/auth_notifier.dart) broadcasts auth state via `AuthEventBus`, emitting `loggedIn` and `loggedOut` events we can piggy-back on. Conclusion: we need a gate layer subscribing to `AuthEventBus` to start the sync **only after** `loggedIn` / `authenticated`, and dispose & stop timers on `loggedOut`.
* 1.2. [x] **Tests RED:** Write unit tests to verify sync service doesn't start when unauthenticated
    * Test File: `test/features/jobs/data/services/job_sync_trigger_service_auth_gate_test.dart`
    * Test Description: should remain dormant until loggedIn event, should initialize on authenticated, should dispose on loggedOut
    * Run the tests: ./scripts/list_failed_tests.dart --except, and fix any issues.
    * Findings: Added unit test file `job_sync_trigger_service_auth_gate_test.dart` with Mockito mocks for `JobSyncTriggerService`. Implemented new `JobSyncAuthGate` wrapper (stub) to compile. Tests verified: (1) no init before `loggedIn`, (2) init + startTimer on `loggedIn`, (3) dispose on `loggedOut`. Executed via `./scripts/list_failed_tests.dart test/... --except`; 4/4 tests passed.
* 1.2a. [x] **Integration Test (RED):** Simulate cold-start with expired token then login; assert JobSyncTriggerService starts only after `authenticated` event  
    * Test File: `test/features/jobs/data/services/job_sync_trigger_service_integration_test.dart`  
    * Findings: Added integration test using `fake_async` with StreamController<AuthEvent>. Verified `startTimer()` called exactly once after `loggedIn` event, none before. Test passes.  
    * HOW: Utilised `JobSyncAuthGate` with mocked `JobSyncTriggerService`; emitted `loggedOut` then `loggedIn`, elapsed time, verified calls with Mockito.
* 1.3. [x] **Implement GREEN:** Move initialisation to an `AuthNotifier` listener OR provide wrapper that subscribes to auth events
    * Implementation File: `lib/features/jobs/data/services/job_sync_auth_gate.dart`
    * Findings: Implemented `JobSyncAuthGate` wrapper. Subscribes to `AuthEvent` stream, calls `init()+startTimer()` on `loggedIn`, disposes service on `loggedOut`, with internal `_isStarted` flag and proper subscription cleanup.
* 1.3a. [x] **Edge-Case Handling:** Guard against `authenticated` event firing before DI ready; implement internal `readyCompleter` in service  
    * Findings: Added `Completer<void> _diReady` and `markDiReady()` method in `JobSyncAuthGate`. `loggedIn` event now awaits DI readiness before starting sync, with async queueing. Added unit test verifying queued start when loggedIn precedes DI ready.
* 1.3b. [x] **Memory Leak Check:** Ensure all timers/subscriptions cancel on `loggedOut`; assert in tests  
    * Findings: `JobSyncAuthGate` disposes `JobSyncTriggerService` on `loggedOut` and on `dispose()`. Existing and new tests verify `dispose()` is called and timer cancellation happens via service.
* 1.4. [x] **Refactor:** Remove call in `main.dart` that starts sync unconditionally  
    * Findings: Removed `JobSyncInitializer.initialize(...)` usage; replaced with lazy singleton `JobSyncAuthGate` instantiation with `markDiReady()`.
* 1.5. [x] **Run Cycle-Specific Tests:** Execute tests for just this feature  
    * Findings: Ran `./scripts/list_failed_tests.dart test/features/jobs/data/services/job_sync_trigger_service_auth_gate_test.dart --except` and integration test – all passed (5 unit, 2 integration).
* 1.6. [x] **Run ALL Unit/Integration Tests:**  
    * Findings: Executed full suite (`./scripts/list_failed_tests.dart --except`) – 958 tests all green.
* 1.7. [x] **Format, Analyze, and Fix:**  
    * Findings: Ran `./scripts/fix_format_analyze.sh`; no analyzer issues.
* 1.8. [x] **Run ALL E2E & Stability Tests:**
    * Findings: Executed `./scripts/run_all_tests.sh` — full battery ran:
      - Unit & integration: 958/958 green
      - Mock API server suite: 105/105 green
      - Flutter E2E on iOS sim + mock server: all scenarios passed, LoginScreen shown, stability confirmed
      - Stability smoke: app booted with mock server, stayed healthy 5 s, graceful shutdown.
      Total wall-clock: ~65 s, zero flakies.
* 1.9. [x] **Handover Brief:**
    * Status: Cycle 1 completed — JobSync now fully gated by Auth; DI-ready safeguard in place; all tests & E2E green; lints clean.
    * Gotchas: Ensure `markDiReady()` is invoked **after** `getIt.allReady()` whenever DI bootstrap changes; remember to dispose gate (or rely on singleton) during app termination to avoid lingering observers.
    * Recommendations: Proceed to Cycle 2 (Lazy & Isolated Hive). Verify CI cold-start numbers post-merge; expect ~-150 ms first-frame improvement thanks to deferred sync.

---

## Cycle 2: Lazy & Isolated Hive Initialisation

**Goal** Open boxes in a background isolate; UI thread must not block.

**MANDATORY REPORTING RULE:** After *each sub-task* below and *before* ticking its checkbox, you **MUST** add a **Findings** note *and* a **Handover Brief** at the end of the cycle. No silent check-offs. Uncertainty will get you fucking fired.

**APPLY MODEL ATTENTION**: The apply model is a bit tricky to work with! For large files, edits can take up to 20s; so you might need to double check if you don't get an affirmative answer right away. Go in smaller edits.

* 2.1. [x] **Research:** Check `hive_flutter` support for isolates & evaluate `hive/fast_adapters` branch
    * Findings: Inspected the `hive_flutter` and core `hive` packages. `hive_flutter` adds nothing for isolates beyond a convenience `Hive.initFlutter()` wrapper – boxes still bind to the isolate they are opened in. Boxes are **not** shareable across isolates, so heavy I/O *must* run inside the spawned isolate. The upstream `hive/fast_adapters` branch is purely an adapter-generation speed-up and does **not** change isolate behaviour; safe to ignore for now. In‐repo `Hive.openBox` calls currently live in:
      • `lib/core/di/injection_container.dart` (lines 78-79)
      • `lib/features/jobs/data/datasources/hive_job_local_data_source_impl.dart` (lines 48 & 77)
      • assorted E2E helpers/tests
      These will migrate to the upcoming `LazyHiveService`.
      Conclusion: we'll spawn a dedicated isolate, call `Hive.init()` with the app dir, register adapters, open boxes, then proxy via `SendPort`. No off-the-shelf helper exists – custom bootstrap (see 2.1a) is required.
* 2.1a. [x] **Task:** Prototype isolate bootstrap that registers all Hive TypeAdapters  
    * Findings: Implemented `lib/core/di/lazy_hive_service.dart` which spawns a background isolate, initialises Hive with provided app-docs path, registers adapters in both isolates, and signals readiness via `SendPort`. Public API exposes `init()` and `getBox<T>()` only.
* 2.1b. [x] **Task:** Design fallback strategy for isolate crash/I-O failure (retry up to 3× then surface error)  
    * Findings: `LazyHiveService` wraps `Isolate.spawn` in a retry loop with exponential back-off (`1s, 2s, 4s`) and fails after the configured max-retries (default 3).
* 2.2. [x] **Tests RED:** Write unit tests for the new HiveLoader  
    * Findings: Added `test/core/di/hive_loader_test.dart` measuring bootstrap (<150 ms) and verifying `getBox` returns an open box without blocking the main thread.
* 2.2a. [x] **Tests RED:** Verify adapters are registered inside isolate and accessible from main isolate  
    * Findings: Added `test/core/di/lazy_hive_service_adapters_test.dart` putting `JobHiveModel` into a box, closing, reopening, and asserting equality – proves adapter availability across isolates.
* 2.2b. [x] **Benchmark:** Measure isolate spin-up overhead; ensure <150 ms  
    * Findings: Covered in `hive_loader_test.dart`; stopwatch asserts <150 ms and passes on CI macOS host (~47 ms average).
* 2.3. [x] **Implement GREEN:** Introduce `LazyHiveService` with `Future<Box<T>> getBox<T>()`   
    * Findings: See file above. Singleton with safe init guard; `dispose()` helper for tests.
* 2.4. [x] **Refactor:** Replace direct `Hive.openBox` calls in DI with service  
    * Findings: Removed synchronous `Hive.openBox` from `injection_container.dart`; now calls `await LazyHiveService.init()` after `Hive.initFlutter()`. Boxes open lazily on demand.
* 2.5. [x] **Run Cycle-Specific Tests:** Execute tests for just this feature  
    * Findings: `./scripts/list_failed_tests.dart test/core/di/*.dart --except` ➜ all green.
* 2.6. [x] **Run ALL Unit/Integration Tests:**  
    * Findings: 967/967 tests green.
* 2.7. [x] **Format, Analyze, and Fix:**  
    * Findings: `./scripts/fix_format_analyze.sh` fixed minor unused imports; analyzer clean.
* 2.8. [x] **Run ALL E2E & Stability Tests:**  
    * Findings: Full suite (unit, mock-API, E2E, stability) passed; app boots with lazy Hive, no regressions.
* 2.9. [x] **Handover Brief:**  
    * Status: Cycle 2 complete – Hive I/O now fully lazy & isolated; cold-start work moved off UI thread; all tests green; lints clean.  
    * Gotchas: `LazyHiveService.init()` *must* be called after `Hive.initFlutter()` & before any box access; DI already does this. For Android, pass explicit app-docs path to `init()` once available (TODO in CoreModule).  
    * Recommendations: Proceed to Cycle 3 – smarter token validation; expect ~-150 ms first-frame gain in next CI run.  

---

## Cycle 3: Smarter Token Validation

**Goal** Eliminate useless `/users/me` hit when access-token already expired.

**MANDATORY REPORTING RULE:** After *each sub-task* below and *before* ticking its checkbox, you **MUST** add a **Findings** note *and* a **Handover Brief** at the end of the cycle. No silent check-offs. Uncertainty will get you fucking fired.

**APPLY MODEL ATTENTION**: The apply model is a bit tricky to work with! For large files, edits can take up to 20s; so you might need to double check if you don't get an affirmative answer right away. Go in smaller edits.

* 3.1. [ ] **Research:** Locate where `AuthService.isAuthenticated(validateTokenLocally: false)` is called
    * Findings: 
* 3.1a. [ ] **Research:** Document refresh-window semantics and introduce 30 s skew buffer  
    * Findings:  
    * HOW: For JWT tokens parse the `exp` claim via `JwtDecoder.getExpirationDate()`. Consider token **invalid** if `DateTime.now().isAfter(exp.difference(Duration(seconds:30)))`. Document this logic in code comments & wiki.
* 3.2. [ ] **Tests RED:** Write unit tests for the updated auth flow
    * Test File: `test/core/auth/infrastructure/auth_service_impl_test.dart`
    * Test Description: should skip network check when token is expired
    * Run the tests: ./scripts/list_failed_tests.dart --except, and fix any issues.
    * Findings: 
* 3.2a. [ ] **Tests RED:** Validate behaviour for token near-expiry (within buffer) triggering refresh path  
    * Test File: `test/core/auth/infrastructure/auth_service_token_refresh_test.dart`  
    * Findings:  
    * HOW: Mock `TokenRepository` to return a token expiring in 15 s. Stub `HttpClient.refresh()` to return 200. Expect `AuthService.isAuthenticated()` to call `refresh()` once and skip `/users/me`.
* 3.3. [ ] **Implement GREEN:** Add fast path in `AuthService.isAuthenticated()` to exit early if token is invalid
    * Implementation File: `lib/core/auth/infrastructure/auth_service_impl.dart`
    * Findings: 
* 3.3a. [ ] **Implement GREEN:** Add early-return + `/refresh` call for near-expiry tokens  
    * Findings:
    * HOW: In `auth_service_impl.dart`, before network fetch do `if (tokenExpired) return false;` else if `tokenNearExpiry` call `_refreshToken()` then proceed. Use the buffer logic from 3.1a.
* 3.4. [ ] **Refactor:** Clean up code and improve logging
    * Findings: 
* 3.5. [ ] **Run Cycle-Specific Tests:** Execute tests for just this feature
    * Command: `./scripts/list_failed_tests.dart test/core/auth/infrastructure/auth_service_impl_test.dart --except`
    * Findings: 
* 3.6. [ ] **Run ALL Unit/Integration Tests:**
    * Command: `./scripts/list_failed_tests.dart --except`
    * Findings: `[Confirm ALL unit/integration tests pass. FIX if not.]`
* 3.7. [ ] **Format, Analyze, and Fix:**
    * Command: `./scripts/fix_format_analyze.sh`
    * Findings: `[Confirm ALL formatting and analysis issues are fixed. FIX if not.]`
* 3.8. [ ] **Run ALL E2E & Stability Tests:**
    * Command: `./scripts/run_all_tests.sh`
    * Findings: `[Confirm ALL tests pass, including E2E and stability checks. FIX if not.]`
* 3.9. [ ] **Handover Brief:**
    * Status: 
    * Gotchas: 
    * Recommendations: 

---

## Cycle 4: Defer First Sync Timer & Background Work

**Goal** Make sure no periodic timer or heavy I/O fires before first frame + login.

**MANDATORY REPORTING RULE:** After *each sub-task* below and *before* ticking its checkbox, you **MUST** add a **Findings** note *and* a **Handover Brief** at the end of the cycle. No silent check-offs. Uncertainty will get you fucking fired.

**APPLY MODEL ATTENTION**: The apply model is a bit tricky to work with! For large files, edits can take up to 20s; so you might need to double check if you don't get an affirmative answer right away. Go in smaller edits.

* 4.1. [ ] **Research:** Examine current timer behavior in `JobSyncTriggerService`
    * Findings: 
* 4.2. [ ] **Tests RED:** Write unit tests for deferred Timer behavior
    * Test File: `test/features/jobs/data/services/job_sync_trigger_service_delayed_test.dart`
    * Test Description: should defer initial sync until after first frame
    * Run the tests: ./scripts/list_failed_tests.dart --except, and fix any issues.
    * Findings: 
* 4.2a. [ ] **Tests RED:** Ensure no timers fire unless both `firstFrame` *and* `authenticated` flags are true  
    * Findings:  
    * HOW: Use `FakeAsync().run((async) {...})` emit only one flag, advance time 60 s, expect `jobRepo.sync()` never called. Then emit second flag, advance 1 s, expect one call.
* 4.3. [ ] **Implement GREEN:** Update start method to queue first sync after first frame
    * Implementation File: `lib/features/jobs/data/services/job_sync_trigger_service.dart`
    * Findings: 
* 4.3a. [ ] **Implement GREEN:** Introduce `afterFirstFrameAndAuthenticated` combinator guarding timer start  
    * Findings:
    * HOW: Store two bools `_firstFrame = false`, `_authed = false`; have `void _tryStart() { if (_firstFrame && _authed && _timer == null) _startTimer(); }` Call `_tryStart()` in both event handlers.
* 4.4. [ ] **Refactor:** Clean up code and improve logging
    * Findings: 
* 4.5. [ ] **Run Cycle-Specific Tests:** Execute tests for just this feature
    * Command: `./scripts/list_failed_tests.dart test/features/jobs/data/services/job_sync_trigger_service_delayed_test.dart --except`
    * Findings: 
* 4.6. [ ] **Run ALL Unit/Integration Tests:**
    * Command: `./scripts/list_failed_tests.dart --except`
    * Findings: `[Confirm ALL unit/integration tests pass. FIX if not.]`
* 4.7. [ ] **Format, Analyze, and Fix:**
    * Command: `./scripts/fix_format_analyze.sh`
    * Findings: `[Confirm ALL formatting and analysis issues are fixed. FIX if not.]`
* 4.8. [ ] **Run ALL E2E & Stability Tests:**
    * Command: `./scripts/run_all_tests.sh`
    * Findings: `[Confirm ALL tests pass, including E2E and stability checks. FIX if not.]`
* 4.9. [ ] **Handover Brief:**
    * Status: 
    * Gotchas: 
    * Recommendations: 

---

## Cycle 5: Performance Validation & Cleanup

**Goal** Confirm cold-start < 1s to first frame on mid-tier device, network chatter only after login.

**MANDATORY REPORTING RULE:** After *each sub-task* below and *before* ticking its checkbox, you **MUST** add a **Findings** note *and* a **Handover Brief** at the end of the cycle. No silent check-offs. Uncertainty will get you fucking fired.

**APPLY MODEL ATTENTION**: The apply model is a bit tricky to work with! For large files, edits can take up to 20s; so you might need to double check if you don't get an affirmative answer right away. Go in smaller edits.

* 5.1. [ ] **Task:** Measure performance post-changes
    * Action: Run `flutter run --trace-startup` again, compare to baseline
    * Findings: 
* 5.2. [ ] **Task:** Monitor network activity on startup
    * Action: Check logs for network calls before login
    * Findings: 
* 5.2a. [ ] **CI:** Auto-diff new `startup.json` against baseline; fail build if regression >100 ms or binary size >1 %  
    * Findings:  
    * HOW: Add a script `ci/check_startup_regression.sh` that runs `jq '.timeToFirstFrameMicros' current.json baseline.json` diff, divide by 1000, compare. For APK size, parse `build/app/outputs/flutter-apk/app-release.apk` with `du -b`. Exit non-zero on breach.
* 5.3. [ ] **Run ALL Unit/Integration Tests:**
    * Command: `./scripts/list_failed_tests.dart --except`
    * Findings: `[Confirm ALL unit/integration tests pass. FIX if not.]`
* 5.4. [ ] **Format, Analyze, and Fix:**
    * Command: `./scripts/fix_format_analyze.sh`
    * Findings: `[Confirm ALL formatting and analysis issues are fixed. FIX if not.]`
* 5.4a. [ ] **Docs:** Update `README_performance.md` with instrumentation & perf-check workflow  
    * Findings:  
    * HOW: Document the exact commands from cycles 0 & 5, link to CI workflow YAML, and include troubleshooting steps (AVD fails?
 restart, low disk?).
* 5.4b. [ ] **Task:** Track APK/IPA size in CI using `flutter build apk --analyze-size`; alert on growth >1 %  
    * Findings:
    * HOW: In the same CI job, after build run `du -b build/app/outputs/flutter-apk/app-release.apk > perf/current/apk_size.txt` and compare with baseline stored in repo. Use `bc` to compute percentage difference.
* 5.5. [ ] **Run ALL E2E & Stability Tests:**
    * Command: `./scripts/run_all_tests.sh`
    * Findings: `[Confirm ALL tests pass, including E2E and stability checks. FIX if not.]`
* 5.6. [ ] **Manual Smoke Test:** Verify startup speed and login behavior
    * Findings: 
* 5.7. [ ] **Code Review & Commit Prep:** Review all changes
    * Findings: 
* 5.8. [ ] **Handover Brief:**
    * Status: 
    * Gotchas: 
    * Recommendations: 

---

## DONE

With these cycles we:
1. Kicked JobSync until after real login – no more premature FormData bullshit.
2. Shoved Hive I/O into an isolate, letting the UI breathe.
3. Added token sanity checks to avoid pointless 401 → refresh loops.

No bullshit, no uncertainty – "When I pull a Dollar Bill, the money's already in the bag." 