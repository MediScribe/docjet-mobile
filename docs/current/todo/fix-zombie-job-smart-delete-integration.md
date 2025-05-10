**FIRST ORDER OF BUSINESS:**
**READ THIS FIRST, MOTHERFUCKER, AND CONFIRM:** [hard-bob-workflow.mdc](../../../.cursor/rules/hard-bob-workflow.mdc)

# TODO: Exorcise Zombie Jobs – Integrate Smart Delete & Slam Logout Race Condition

**Goal:**
1.  **Wire the swipe-to-delete UI and `JobListCubit` to the new `smartDeleteJob` flow** so that orphan jobs (no server counterpart or server 404) are purged instantly instead of being stuck in `pendingDeletion` limbo. This isn't some feel-good bullshit; it's about immediate, decisive action.
2.  **Guarantee logout is a fucking nuclear option** – once `AuthEvent.loggedOut` fires and `clearUserData()` is called, *nothing* is allowed to resurrect or re-persist jobs. This removes the "failed-after-logout" race that keeps phantom items alive. We're building a fortress, not a goddamn sandcastle.

We're killing uncertainty, Dollar-Bill style. "I'm not uncertain."

---

## Target Flow / Architecture (MANDATORY – No Bullshit Visual)

```mermaid
sequenceDiagram
    participant User
    participant JobListPlayground(UI)
    participant JobListCubit
    participant SmartDeleteJobUseCase
    participant JobRepository
    participant JobDeleterService
    participant ApiJobRemoteDataSource
    participant HiveJobLocalDataSource

    User->>JobListPlayground: Swipe -> confirmDismiss
    JobListPlayground->>JobListCubit: smartDeleteJob(localId)
    JobListCubit->>SmartDeleteJobUseCase: call(localId)
    SmartDeleteJobUseCase->>JobRepository: smartDeleteJob(localId)
    JobRepository->>JobDeleterService: attemptSmartDelete(localId)
    JobDeleterService->>HiveJobLocalDataSource: getJobById(localId)
    alt serverId == null
        JobDeleterService->>HiveJobLocalDataSource: permanentlyDeleteJob(localId)
        HiveJobLocalDataSource-->>JobDeleterService: Right(unit)
    else serverId != null & online
        JobDeleterService->>ApiJobRemoteDataSource: HEAD /jobs/{serverId} (or GET)
        alt 404 Not Found
            JobDeleterService->>HiveJobLocalDataSource: permanentlyDeleteJob(localId)
        else 200 OK / timeout / network error / other HTTP errors
            JobDeleterService->>HiveJobLocalDataSource: markPendingDeletion(localId)
        end
    else offline
        JobDeleterService->>HiveJobLocalDataSource: markPendingDeletion(localId)
    end
    JobDeleterService-->>JobRepository: Right(true_if_purged_false_if_marked)
    JobRepository-->>SmartDeleteJobUseCase: Right(…)
    SmartDeleteJobUseCase-->>JobListCubit: Right(…)
    Note over JobListCubit: UI already removed item optimistically. WatchJobs stream confirms final state.

    %% Logout Race Guard
    AuthEventBus-->>JobSyncOrchestratorService: AuthEvent.loggedOut
    JobSyncOrchestratorService->>JobSyncProcessorService: notifyLogoutInProgress() / setFlag()
    JobSyncOrchestratorService->>HiveJobLocalDataSource: clearUserData()
    Note over JobSyncProcessorService: Before _localDataSource.saveJob() in _handleSyncError():
IF isLogoutInProgress THEN DO NOT SAVE.
    JobSyncProcessorService-x HiveJobLocalDataSource: ✋ block writes while logoutInProgress
```

---

**MANDATORY REPORTING RULE:** For **every** task/cycle below, **before check-off and moving on to the next todo**, the dev must (a) write a brief *Findings* paragraph summarizing *what was done and observed* and (b) a *Handover Brief* summarising status at theend of the cycle, edge-cases/gotchas, and next-step readiness **inside this doc** before ticking the checkbox. No silent check-offs allowed – uncertainty gets you fucking fired. Like Mafee forgetting the shorts, don't be that guy.

---

## Cycle 0: Setup & Prerequisite Checks (The "Due Diligence" Cycle)

**Goal** Verify all existing plumbing for `smartDeleteJob` is sound, confirm no `SmartDeleteJobUseCase` exists, trace the current UI deletion path, and pinpoint exact locations for the logout race guard. We don't build on fucking quicksand.

**MANDATORY REPORTING RULE:** After *each sub-task* below and *before* ticking its checkbox, you **MUST** add a **Findings** note *and* a **Handover Brief**. No silent check-offs. Uncertainty will get you fucking fired.

**APPLY MODEL ATTENTION**: The apply model is a bit tricky to work with! For large files, edits can take up to 20s; so you might need to double check if you don't get an affirmative answer right away. Go in smaller edits.

*   0.1. [x] **Task:** Locate `JobRepository.smartDeleteJob()` method and its unit tests.
    *   Action: Run `grep -R "smartDeleteJob(" lib/ test/ | cat`. Open the `job_repository_impl.dart` and `job_repository_impl_test.dart` files. Confirm the method signature `Future<Either<Failure, bool>> smartDeleteJob(String localId)`.
    *   Findings: Path to impl: `lib/features/jobs/data/repositories/job_repository_impl.dart`. Path to test: `test/features/jobs/data/repositories/job_repository_impl_test.dart`. Signature `Future<Either<Failure, bool>> smartDeleteJob(String localId)` confirmed. All 18 tests in `job_repository_impl_test.dart` are passing.
*   0.2. [x] **Task:** Confirm no **SmartDeleteJobUseCase** yet exists.
    *   Action: Perform a project-wide symbol search for `SmartDeleteJobUseCase`.
    *   Findings: Confirmed: "No results found" for a class or file specifically named `SmartDeleteJobUseCase`. Existing related components like `DeleteJobUseCase` and `JobDeleterService.attemptSmartDelete` were found, but no dedicated `SmartDeleteJobUseCase`.
*   0.3. [x] **Task:** Trace UI call-chain from `JobListPlayground.confirmDismiss` to `JobListCubit.deleteJob`.
    *   Action: Open `lib/features/jobs/presentation/pages/job_list_playground.dart`. Follow the `deleteJob` call into `lib/features/jobs/presentation/cubit/job_list_cubit.dart`.
    *   Findings: Current call path: `JobListPlayground._buildDismissibleJobItem.confirmDismiss` (line 465) calls `context.read<JobListCubit>().deleteJob(job.localId)`. `JobListCubit.deleteJob` (line 153) then calls `_deleteJobUseCase(DeleteJobParams(localId: localId))`. No intermediate layers noted beyond the UseCase.
*   0.4. [x] **Task:** Evaluate current logout data clearing and sync error handling for race condition.
    *   Action:
        1.  Inspect `JobRepositoryImpl.clearUserData()` and its callers (likely `AuthNotifier` or similar on logout event).
        2.  Inspect `JobSyncProcessorService._handleSyncError()` - specifically the part where it calls `_localDataSource.saveJob(updatedJob)` to persist `SyncStatus.failed`.
        3.  Check how `JobSyncOrchestratorService` (or its equivalent) manages the lifecycle of `JobSyncProcessorService` and if it listens to `AuthEventBus` for logout.
    *   Findings: 
        1.  `JobRepositoryImpl` listens to `AuthEventBus` for `AuthEvent.loggedOut` (fired by `AuthServiceImpl` or `AuthInterceptor`). On logout, its `_handleLogout` calls `_localDataSource.clearUserData()` (implemented in `HiveJobLocalDataSourceImpl`). `JobRepositoryImpl.clearUserData()` is not called directly externally.
        2.  `JobSyncProcessorService._handleSyncError` (lines 206-231 in `job_sync_processor_service.dart`) calls `await _localDataSource.saveJob(updatedJob);` (line 223) to persist job with `SyncStatus.failed` or `SyncStatus.error`.
        3.  `JobSyncOrchestratorService` listens to `AuthEventBus`. Its `_handleLoggedOut` sets an internal `_isLoggedOut = true` flag. This flag prevents *new* sync cycles from starting and aborts *currently running* sync loops between job processing. It does **not** pass a logout status directly to `JobSyncProcessorService` for `_handleSyncError` to check before saving, nor does it explicitly cancel ongoing async operations within `_processorService.processJobSync/Deletion` if one is mid-flight when logout occurs. The `_processorService` is injected and its methods are called by the orchestrator; no specific lifecycle management like 'dispose' or 'cancel' is invoked on `_processorService` upon logout, beyond the orchestrator stopping its calls to it.
*   0.5. [x] **Update Plan:** Based on findings, confirm that data-layer changes for smart delete are indeed complete. Refine tasks for Cycle 1 (UseCase creation) and Cycle 4 (Logout Guard) if any unexpected complexities arise.
    *   Findings: Plan confirmed. `smartDeleteJob` in `JobRepositoryImpl` and its delegation to `JobDeleterService.attemptSmartDelete` are robust. Data-layer changes for smart delete are complete. The logout race condition in `JobSyncProcessorService._handleSyncError` is confirmed, as it currently does not check any logout status before saving a job. Cycle 4's plan to introduce a guard mechanism is appropriate. No unexpected complexities arose that require significant plan changes for Cycle 1 or 4.
*   0.6. [x] **Handover Brief:**
    *   Status: Recon complete. Data path for `smartDeleteJob` via `JobRepositoryImpl` and `JobDeleterService` is verified and robust with existing tests passing. UI call chain from `JobListPlayground` to `JobListCubit.deleteJob` (currently using `DeleteJobUseCase`) is identified. The logout race condition point in `JobSyncProcessorService._handleSyncError` (specifically the `_localDataSource.saveJob` call) is confirmed, and the existing logout handling in `JobSyncOrchestratorService` via an `_isLoggedOut` flag is understood to be insufficient on its own to prevent this specific race.
    *   Gotchas: No major surprises. The primary gotcha is the subtlety of the logout race: `JobSyncOrchestratorService` stops *initiating* new work or breaks loops, but an already in-flight `_handleSyncError` in `JobSyncProcessorService` can still complete its `saveJob` call after logout has been signaled to the orchestrator but before the processor is aware or its operation is completed/cancelled.
    *   Recommendations: Proceed to Cycle 1 for `SmartDeleteJobUseCase` creation (TDD). Cycle 4 will then address the logout race by implementing a more direct guard for `JobSyncProcessorService`.

---

## Cycle 1: Introduce **SmartDeleteJobUseCase** (TDD)

**Goal** Add a dedicated, clean, and testable domain layer UseCase to orchestrate the `JobRepository.smartDeleteJob` call. This keeps our layers SOLID, not a fucking spaghetti mess.

**MANDATORY REPORTING RULE:** After *each sub-task* below and *before* ticking its checkbox, you **MUST** add a **Findings** note *and* a **Handover Brief** at the end of the cycle.

*   1.1. [ ] **Research:** Decision: New `SmartDeleteJobUseCase` vs. modifying `DeleteJobUseCase`.
    *   Action: Consider if `DeleteJobUseCase` (which currently implies "mark for deletion") can be altered to return `Either<Failure, bool>` and handle the smart logic, or if a new, explicitly named `SmartDeleteJobUseCase` is cleaner.
    *   Findings: [Document decision and rationale. *Hard Bob strongly prefers explicit over implicit. A new UseCase is likely cleaner unless `DeleteJobUseCase` is only used by swipe-to-delete.*]
*   1.2. [ ] **Tests RED:** Create `test/features/jobs/domain/usecases/smart_delete_job_use_case_test.dart`.
    *   Test Description:
        *   `should call JobRepository.smartDeleteJob and return Right(true) when repository indicates immediate purge`
        *   `should call JobRepository.smartDeleteJob and return Right(false) when repository indicates mark for deletion`
        *   `should propagate Left(failure) when JobRepository.smartDeleteJob fails`
        *   Mock `JobRepository`.
    *   Run the tests: `./scripts/list_failed_tests.dart test/features/jobs/domain/usecases/smart_delete_job_use_case_test.dart --except`
    *   Findings: [Confirm 3 tests are written and fail as expected (No implementation yet). Document any issues writing these tests.]
*   1.3. [ ] **Implement GREEN:** Create `lib/features/jobs/domain/usecases/smart_delete_job_use_case.dart`.
    *   Action: Write the minimal code for `SmartDeleteJobUseCase` (class, constructor, `call` method) to make the tests pass. It should take `JobRepository` in constructor and `SmartDeleteJobParams` (with `localId`) in `call`.
    *   Findings: [Confirm code written and tests pass. Note any implementation challenges.]
*   1.4. [ ] **Refactor:** Clean up `SmartDeleteJobUseCase` and its tests.
    *   Action: Ensure constructor uses named `{required JobRepository repository}`. `SmartDeleteJobParams` should extend `Equatable`. Ensure test names are descriptive.
    *   Findings: [Describe refactoring. Confirm tests still pass. Run `dart analyze lib/features/jobs/domain/usecases/smart_delete_job_use_case.dart test/features/jobs/domain/usecases/smart_delete_job_use_case_test.dart`.]
*   1.5. [ ] **Run Cycle-Specific Tests:**
    *   Command: `./scripts/list_failed_tests.dart test/features/jobs/domain/usecases/smart_delete_job_use_case_test.dart --except`
    *   Findings: [Confirm tests pass. List failures and fixes if any.]
*   1.6. [ ] **Run ALL Unit/Integration Tests:**
    *   Command: `./scripts/list_failed_tests.dart --except`
    *   Findings: `[Confirm ALL unit/integration tests pass. FIX if not.]`
*   1.7. [ ] **Format, Analyze, and Fix:**
    *   Command: `./scripts/fix_format_analyze.sh`
    *   Findings: `[Confirm ALL formatting and analysis issues are fixed. FIX if not.]`
*   1.8. [ ] **Run ALL E2E & Stability Tests:**
    *   Command: `./scripts/run_all_tests.sh`
    *   Findings: `[Confirm ALL tests pass. E2E might not be affected yet.]`
*   1.9. [ ] **Handover Brief:**
    *   Status: [e.g., `SmartDeleteJobUseCase` created, tested, and follows domain layer best practices.]
    *   Gotchas: [Any tricky bits? e.g., "Deciding on Params object vs. simple String for UseCase input."]
    *   Recommendations: [Ready for Cycle 2: Cubit integration.]

---

## Cycle 2: Cubit & DI Wiring for Smart Deletion

**Goal** Expose the `SmartDeleteJobUseCase` logic through `JobListCubit.smartDeleteJob()` and correctly register all new dependencies in the DI container. No fucking cowboys hooking things up directly.

**MANDATORY REPORTING RULE:** After *each sub-task* below and *before* ticking its checkbox, you **MUST** add a **Findings** note *and* a **Handover Brief** at the end of the cycle.

*   2.1. [ ] **Tests RED:** Update `test/features/jobs/presentation/cubit/job_list_cubit_test.dart`. Add a new `group('smartDeleteJob', () { ... });`.
    *   Test Description:
        *   `when SmartDeleteJobUseCase returns Right(true) (immediate purge), it should log success and not emit new state beyond optimistic UI updates` (optimistic UI is in widget, cubit just confirms/logs).
        *   `when SmartDeleteJobUseCase returns Right(false) (marked for deletion), it should log success and not emit new state beyond optimistic UI updates`.
        *   `when SmartDeleteJobUseCase returns Left(Failure), it should call AppNotifierService.show() with error message and roll back optimistic UI if applicable` (rollback logic might be more complex, focus on notifier call for now).
        *   Mock `SmartDeleteJobUseCase` and `AppNotifierService`.
    *   Run the tests: `./scripts/list_failed_tests.dart test/features/jobs/presentation/cubit/job_list_cubit_test.dart --except`
    *   Findings: [Confirm new tests written and fail. Note challenges, e.g., "Verifying AppNotifierService interaction accurately." Rollback testing might be deferred to widget tests if too complex here.]
*   2.2. [ ] **Implement GREEN:** Modify `lib/features/jobs/presentation/cubit/job_list_cubit.dart`.
    *   Action:
        1.  Add `final SmartDeleteJobUseCase _smartDeleteJobUseCase;` to the Cubit.
        2.  Update constructor to accept `required SmartDeleteJobUseCase smartDeleteJobUseCase`.
        3.  Implement `Future<void> smartDeleteJob(String localId)` method. Call `_smartDeleteJobUseCase`, use `fold` to handle `Either`, log outcomes, and call `_appNotifierService.show()` on failure.
    *   Findings: [Confirm code written, tests pass. Note: Cubit should *not* directly manipulate `_displayedJobs` or `_locallyRemovedIds` from playground; it orchestrates the backend call and relies on stream for list updates or uses `AppNotifierService` for transient errors.]
*   2.3. [ ] **Dependency Injection:** Modify `lib/features/jobs/di/jobs_module.dart`.
    *   Action:
        1.  Register `SmartDeleteJobUseCase`: `getIt.registerLazySingleton(() => SmartDeleteJobUseCase(getIt()));` (ensure `JobRepository` is already registered).
        2.  Update `JobListCubit` factory registration: `getIt.registerFactory<JobListCubit>(() => JobListCubit(..., smartDeleteJobUseCase: getIt(), ...));`.
    *   Findings: [Confirm DI registration is correct. Application should compile and run.]
*   2.4. [ ] **Refactor:** Ensure `JobListCubit.smartDeleteJob` is clean, well-logged, and adheres to the 20 LOC guideline.
    *   Findings: [Describe refactoring. Confirm tests still pass. Run `dart analyze` on cubit and DI module.]
*   2.5. [ ] **Run Cycle-Specific Tests:**
    *   Command: `./scripts/list_failed_tests.dart test/features/jobs/presentation/cubit/job_list_cubit_test.dart --except` and `./scripts/list_failed_tests.dart test/features/jobs/di/jobs_module_test.dart --except` (if you have DI module tests).
    *   Findings: [Confirm tests pass.]
*   2.6. [ ] **Run ALL Unit/Integration Tests:**
    *   Command: `./scripts/list_failed_tests.dart --except`
    *   Findings: `[Confirm ALL pass.]`
*   2.7. [ ] **Format, Analyze, and Fix:**
    *   Command: `./scripts/fix_format_analyze.sh`
    *   Findings: `[Confirm clean.]`
*   2.8. [ ] **Run ALL E2E & Stability Tests:**
    *   Command: `./scripts/run_all_tests.sh`
    *   Findings: `[Confirm ALL pass. E2E might still not reflect UI changes yet.]`
*   2.9. [ ] **Handover Brief:**
    *   Status: [e.g., `JobListCubit` now has `smartDeleteJob` method, wired to `SmartDeleteJobUseCase`. DI updated. All tests green.]
    *   Gotchas: [e.g., "Initial thought was to have Cubit manage optimistic list, but decided against it to keep Cubit simpler and rely on widget state + stream for UI."]
    *   Recommendations: [Proceed to Cycle 3: UI Integration.]

---

## Cycle 3: UI Hook-up – Playground First, Then Production

**Goal** Replace the old `deleteJob()` call in `JobListPlayground`'s `confirmDismiss` with the new `cubit.smartDeleteJob()`. Ensure widget tests verify the call and the UI behaves (item removed, no error if success). Then, propagate this change to the actual production Job List UI.

**MANDATORY REPORTING RULE:** After *each sub-task* below and *before* ticking its checkbox, you **MUST** add a **Findings** note *and* a **Handover Brief** at the end of the cycle.

*   3.1. [ ] **Research:** Identify `confirmDismiss` or equivalent swipe-delete handlers in the *production* Job List UI (e.g., `JobListPage.dart` or similar).
    *   Action: Project search for `Dismissible` widgets handling `JobViewModel` or similar, outside of the playground.
    *   Findings: [List file paths and widget names for production UI swipe-delete implementations.]
*   3.2. [ ] **Tests RED (Playground):** Update `test/features/jobs/presentation/pages/job_list_playground_test.dart`.
    *   Test Description:
        *   `on swipe, should call mockJobListCubit.smartDeleteJob with correct jobId`.
        *   (Optional, if not covered by optimistic UI nature): `if smartDeleteJob indicates immediate purge, item is removed from list`.
        *   (Optional): `if smartDeleteJob indicates fallback, item is still removed (due to optimistic UI)`.
    *   Run the tests: `./scripts/list_failed_tests.dart test/features/jobs/presentation/pages/job_list_playground_test.dart --except`
    *   Findings: [Confirm tests for playground fail because `deleteJob` is still called.]
*   3.3. [ ] **Implement GREEN (Playground):** Edit `lib/features/jobs/presentation/pages/job_list_playground.dart`.
    *   Action: In `_buildDismissibleJobItem`'s `confirmDismiss`, change `context.read<JobListCubit>().deleteJob(job.localId);` to `context.read<JobListCubit>().smartDeleteJob(job.localId);`.
    *   Findings: [Confirm playground widget tests pass. Manually verify in playground: swipe an orphan (if mockable) vs. a normal job.]
*   3.4. [ ] **Refactor (Playground):** The existing optimistic UI in `job_list_playground.dart` (`_locallyRemovedIds`, `_displayedJobs.removeWhere`) should still largely work. Ensure it's clean. The Cubit's `smartDeleteJob` doesn't directly alter these; it triggers backend logic.
    *   Findings: [Confirm playground UI code is clean. `dart analyze` the file.]
*   3.5. [ ] **Extend to Production UI:** Repeat steps 3.2-3.4 for the production Job List UI identified in 3.1. This means:
    *   Update/add widget tests for the production swipe-delete.
    *   Change the `cubit.deleteJob()` call to `cubit.smartDeleteJob()`.
    *   Ensure any local optimistic UI logic in production is compatible.
    *   Findings: [Document changes and test results for *each* production UI file modified.]
*   3.6. [ ] **Run ALL Widget Tests:**
    *   Command: `./scripts/list_failed_tests.dart test/features/jobs/presentation/ --except` (or more specific paths if known)
    *   Findings: [Confirm all relevant widget tests pass.]
*   3.7. [ ] **Run ALL Unit/Integration Tests:**
    *   Command: `./scripts/list_failed_tests.dart --except`
    *   Findings: `[Confirm ALL pass.]`
*   3.8. [ ] **Format, Analyze, and Fix:**
    *   Command: `./scripts/fix_format_analyze.sh`
    *   Findings: `[Confirm clean.]`
*   3.9. [ ] **Run ALL E2E & Stability Tests:**
    *   Command: `./scripts/run_all_tests.sh`
    *   Findings: `[Confirm ALL pass. E2E should now reflect new behavior.]`
*   3.10. [ ] **Handover Brief:**
    *   Status: [e.g., Swipe-to-delete in playground (and production UI) now uses `smartDeleteJob`. Optimistic UI patterns maintained.]
    *   Gotchas: [e.g., "Production UI had slightly different optimistic removal logic that needed adjustment."]
    *   Recommendations: [Proceed to Cycle 4: Logout Race Condition fix.]

---

## Cycle 4: Kill the Logout Race Condition

**Goal** Prevent `JobSyncProcessorService` (or any other background job writer) from saving job updates (like `SyncStatus.failed`) to Hive *after* `AuthEvent.loggedOut` has been processed and `clearUserData()` initiated. This makes logout the final fucking word.

**MANDATORY REPORTING RULE:** After *each sub-task* below and *before* ticking its checkbox, you **MUST** add a **Findings** note *and* a **Handover Brief** at the end of the cycle.

*   4.1. [ ] **Research:** Confirm `JobSyncProcessorService._handleSyncError` is the primary place where jobs are saved with `SyncStatus.failed` or `SyncStatus.error` during sync operations. Identify how `JobSyncOrchestratorService` manages its lifecycle and receives logout events.
    *   Action: Review `JobSyncProcessorService.processJobSync`, `processJobDeletion`, and especially `_handleSyncError`. Review `JobSyncOrchestratorService`'s `AuthEventBus` subscription and disposal logic.
    *   Findings: [Confirm `_handleSyncError` saves jobs. Detail how orchestrator learns about logout.]
*   4.2. [ ] **Tests RED:** In `test/features/jobs/data/services/job_sync_processor_service_test.dart`, add tests for `_handleSyncError` (or its public callers like `processJobSync`/`processJobDeletion` if `_handleSyncError` is private).
    *   Test Description:
        *   `when logout is in progress, _handleSyncError should NOT call localDataSource.saveJob`.
        *   Mock `JobLocalDataSource` and a way to signify "logout in progress" (e.g., a mock `LogoutGuardService` or a flag on a mock `JobSyncOrchestratorService`).
    *   Run the tests: `./scripts/list_failed_tests.dart test/features/jobs/data/services/job_sync_processor_service_test.dart --except`
    *   Findings: [Confirm tests fail because `saveJob` is still called.]
*   4.3. [ ] **Implement GREEN:**
    *   Action:
        1.  In `JobSyncOrchestratorService` (or a new `LogoutGuardService` it manages):
            *   Add a boolean flag, e.g., `_isLogoutInProgress = false;`.
            *   When `AuthEvent.loggedOut` is received: set `_isLogoutInProgress = true;` *before* calling `clearUserData()` and *before* disposing/cancelling the `JobSyncProcessorService`.
            *   Provide a getter `bool get isLogoutInProgress => _isLogoutInProgress;`. Reset flag on new login if necessary.
        2.  Inject `JobSyncOrchestratorService` (or the `LogoutGuardService`) into `JobSyncProcessorService`.
        3.  In `JobSyncProcessorService._handleSyncError`, before `await _localDataSource.saveJob(updatedJob);`, add a check: `if (_orchestrator.isLogoutInProgress) { _logger.w('Logout in progress, skipping save of job ${job.localId} with error state.'); return; }`.
    *   Findings: [Confirm code implemented and tests pass. Ensure orchestrator sets flag correctly relative to `clearUserData`.]
*   4.4. [ ] **Refactor:** Ensure the logout guard mechanism is clean, robust, and doesn't introduce circular dependencies. Consider if a dedicated `CancelToken` or stream subscription management in `JobSyncOrchestratorService` is better for stopping the processor than just a flag check (though flag check is simpler for blocking writes).
    *   Findings: [Describe refactoring. `dart analyze` relevant files.]
*   4.5. [ ] **Run Cycle-Specific Tests:**
    *   Command: `./scripts/list_failed_tests.dart test/features/jobs/data/services/job_sync_processor_service_test.dart --except` (and orchestrator tests if modified).
    *   Findings: [Confirm tests pass.]
*   4.6. [ ] **Run ALL Unit/Integration Tests:**
    *   Command: `./scripts/list_failed_tests.dart --except`
    *   Findings: `[Confirm ALL pass.]`
*   4.7. [ ] **Format, Analyze, and Fix:**
    *   Command: `./scripts/fix_format_analyze.sh`
    *   Findings: `[Confirm clean.]`
*   4.8. [ ] **Run ALL E2E & Stability Tests:**
    *   Command: `./scripts/run_all_tests.sh`
    *   Findings: `[Confirm ALL pass. This fix is critical for E2E stability on logout.]`
*   4.9. [ ] **Handover Brief:**
    *   Status: [e.g., Logout race condition addressed. `JobSyncProcessorService` now respects a logout flag and avoids saving jobs if logout is underway.]
    *   Gotchas: [e.g., "Ensuring the orchestrator sets the flag *before* `clearUserData` and processor cancellation was key."]
    *   Recommendations: [Proceed to final polish and documentation.]

---

## Cycle N: Final Polish, Documentation & Cleanup

**Goal** Update all relevant documentation, rigorously test edge cases (especially offline + logout scenarios), perform manual smoke tests, and ensure the codebase is pristine. Leave no stone unturned. "You get one life. Blaze on." - Lara Axelrod.

**MANDATORY REPORTING RULE:** After *each sub-task* below and *before* ticking its checkbox, you **MUST** add a **Findings** note *and* a **Handover Brief** at the end of the cycle.

*   N.1. [ ] **Task:** Update Architecture Docs.
    *   File:
        *   `docs/current/feature-job-dataflow.md`: Update delete flow diagram and description to show `SmartDeleteJobUseCase` and its outcomes. Clearly document the logout write-block logic in the sync error handling section.
        *   `docs/current/feature-job-presentation.md`: Briefly mention that swipe-delete now uses "smart" logic for orphan removal in the UI interaction patterns.
        *   If `SmartDeleteJobUseCase` was created, add it to relevant domain layer diagrams/docs.
    *   Findings: [Confirm docs accurately reflect the new smart delete UI flow and the logout guard mechanism.]
*   N.2. [ ] **Task:** Review and Remove Any Dead Code/Old Logic.
    *   Action: Specifically check if the old `JobListCubit.deleteJob` is now entirely unused. If so, deprecate or remove it and its direct dependencies if they aren't used elsewhere (e.g., if `DeleteJobUseCase` becomes obsolete).
    *   Findings: [Confirm dead code removed or deprecated with clear `@Deprecated` tags and migration paths. Verify no build errors.]
*   N.3. [ ] **Manual Offline Test (Smart Delete):**
    *   Action: Go into airplane mode. In the app (playground or prod), swipe-delete a job that has a `serverId` (i.e., it *would* try a network call if online).
    *   Findings: [Confirm the job is marked as `pendingDeletion` (or equivalent UI indicating it couldn't be smart-deleted immediately) and doesn't cause an error due to being offline. Confirm it syncs for deletion once back online.]
*   N.4. [ ] **Manual End-to-End Auth Logout Test (Race Condition):**
    *   Action:
        1.  Ensure a job is in a state where it *will* fail to sync (e.g., bad data that server will reject, or temporarily break server delete endpoint if possible).
        2.  Trigger a sync.
        3.  While the sync is attempting (and expected to fail for that job), trigger a logout from the app.
        4.  Restart the app and log back in (or check local DB state if possible before login).
    *   Findings: [The job that failed to sync *must not* reappear. Confirm local job data is properly cleared.]
*   N.5. [ ] **Run ALL Unit/Integration Tests:**
    *   Command: `./scripts/list_failed_tests.dart --except`
    *   Findings: `[Confirm ALL unit/integration tests pass. FIX if not.]`
*   N.6. [ ] **Format, Analyze, and Fix:**
    *   Command: `./scripts/fix_format_analyze.sh`
    *   Findings: `[Confirm ALL formatting and analysis issues are fixed. FIX if not.]`
*   N.7. [ ] **Run ALL E2E & Stability Tests:**
    *   Command: `./scripts/run_all_tests.sh`
    *   Findings: `[Confirm ALL tests pass, including E2E and stability checks. These manual tests are good candidates for E2E automation if not already covered.]`
*   N.8. [ ] **Code Review & Commit Prep:**
    *   Action: Review all staged changes with `git diff --staged | cat`. Ensure adherence to project guidelines, clean architecture, and Hard Bob principles.
    *   Findings: [Confirm code is clean, follows principles, and is ready for a Hard Bob Commit. No fucking bullshit left behind.]
*   N.9. [ ] **Handover Brief:**
    *   Status: [e.g., Zombie Job Exorcism complete. Smart delete fully integrated. Logout race condition nuked. All tests passing, docs updated. Code is fucking pristine.]
    *   Gotchas: [Any final caveats or observations? e.g., "Manual E2E for logout race was tricky to time but essential."]
    *   Recommendations: [Merge it. Ship it. Tell Axe the problem is solved, permanently.]

---

## DONE

With these cycles we will have:
1.  Routed swipe-delete functionality through the new, fully-tested `SmartDeleteJobUseCase` pipeline, ensuring orphans are purged immediately.
2.  Obliterated the logout race condition by implementing a robust guard that prevents late Hive writes after `clearUserData` is initiated.
3.  Updated all relevant architecture and feature documentation so future devs don't pull a Mafee and reintroduce these bugs.
4.  Kept 💯 percent of tests green and the codebase squeaky clean – because we are *not* renting space to uncertainty.

Now get to fucking work, or as Wags would say: *"If you're scared, buy a dog."* 