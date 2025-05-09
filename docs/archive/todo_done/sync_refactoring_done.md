# Job Sync Service Refactoring Plan

This document outlines the steps to refactor the monolithic `JobSyncService` into a more manageable structure with an `Orchestrator` and a `Processor`.

## TODO List - TDD, Hard Bob Style

0. Do only ONE main TODO at the time, then stop!
1. Test belong to tests, not lib. Absolute package imports only. 
2. If you cant find something, stop bitching, use grep.
3. TDD, TDD, TDD! Proceed in baby steps: test red, implement / refactor, gree. Next.
4. After major code edits, run dart analyze and fix ALL linter issues. It will safe you a ton of time.
5. You can run all the terminal commands directly yourself
6. Once done, tick it off in this document. 
7. One last  ./scripts/list_failed_tests.sh - fix anything broken
8. Hard Bob Commit. Stage all.

### Phase 1: Internal Refactoring (No new files yet)

-   [x] **1. Isolate `syncSingleJob` Failure Logic:**
    -   [x] Create private helper `_handleRemoteSyncFailure(Job job, dynamic error)` in `JobSyncService`.
    -   [x] Move `catch` block logic from `syncSingleJob` into the helper.
    -   [x] Update `syncSingleJob` to call the helper.
    -   [x] Run `flutter test test/features/jobs/data/services/sync_single_job_test.dart` (must pass).

-   [x] **2. Isolate `syncPendingJobs` Deletion Logic:**
    -   [x] Create private helper `_processSingleDeletion(Job jobToDelete)` in `JobSyncService`.
    -   [x] Move deletion loop logic (API call, try/catch, `_permanentlyDeleteJob` call) into the helper.
    -   [x] Update `syncPendingJobs` to call the helper within the loop.
    -   [x] Run `flutter test test/features/jobs/data/services/sync_pending_jobs_test.dart` (must pass).

### Phase 2: Splitting the Service

-   [x] **3. Create `JobSyncProcessorService`:**
    -   [x] Create `lib/features/jobs/data/services/job_sync_processor_service.dart`.
    -   [x] Define `JobSyncProcessorService` class.
    *   [x] Move `syncSingleJob` (rename to `processJobSync`) to `JobSyncProcessorService`.
    *   [x] Move `_processSingleDeletion` (rename to `processJobDeletion`) to `JobSyncProcessorService`.
    *   [x] Move `_handleRemoteSyncFailure` (make private) to `JobSyncProcessorService`.
    *   [x] Move `_handleSyncError` (make private) to `JobSyncProcessorService`.
    *   [x] Move `_permanentlyDeleteJob` (make private) to `JobSyncProcessorService`.
    *   [x] Define dependencies: `JobLocalDataSource`, `JobRemoteDataSource`, `FileSystem`.

-   [x] **4. Refactor `JobSyncService` into `JobSyncOrchestratorService`:**
    -   [x] Rename `JobSyncService` class and file to `JobSyncOrchestratorService`.
    -   [x] Update dependencies: Include `NetworkInfo`, `JobLocalDataSource`, `JobSyncProcessorService`. Remove `JobRemoteDataSource`, `FileSystem`.
    -   [x] Modify `syncPendingJobs` to call `_processorService.processJobSync(job)`.
    -   [x] Modify `syncPendingJobs` to call `_processorService.processJobDeletion(job)`.
    -   [x] Remove unused methods (`syncSingleJob`, `_processSingleDeletion`, helpers) from orchestrator.

-   [x] **5. Update Dependency Injection:**
    -   [x] Register `JobSyncProcessorService` in DI container.
    -   [x] Update registration for `JobSyncOrchestratorService` with new dependencies.
    -   [x] Verify DI setup manually (and update `JobRepositoryImpl` registration).

### Phase 3: Splitting the Tests

-   [x] **6. Create `job_sync_processor_service_test.dart`:**
    -   [x] Copy `sync_single_job_test.dart` to `job_sync_processor_service_test.dart`.
    -   [x] Update `main`, imports, mocks (`LocalDS`, `RemoteDS`, `FileSystem`), and tested class (`JobSyncProcessorService`).
    -   [x] Rename test groups/descriptions (`syncSingleJob` -> `processJobSync`).
    -   [x] Fix existing `processJobSync` tests (verification logic).
    -   [x] Add tests for `processJobDeletion` (success/failure paths).
    -   [x] Run `flutter test test/features/jobs/data/services/job_sync_processor_service_test.dart` (must pass).

-   [x] **7. Refactor `sync_pending_jobs_test.dart` to `job_sync_orchestrator_service_test.dart`:**
    -   [x] Rename `sync_pending_jobs_test.dart` file and update `main`, imports, tested class (`JobSyncOrchestratorService`).
    -   [x] Update mocks: Remove `RemoteDS`, `FileSystem`. Add mock for `JobSyncProcessorService`.
    -   [x] Update arrangements/verifications: Verify calls to mocked `_processorService.processJobSync` and `_processorService.processJobDeletion`.
    -   [x] Run `flutter test test/features/jobs/data/services/job_sync_orchestrator_service_test.dart` (must pass).

-   [x] **8. Delete Old Test File & Final Verification:**
    -   [x] Delete `test/features/jobs/data/services/sync_single_job_test.dart`.
    -   [x] Run `flutter test lib/features/jobs/data/services/` (all tests must pass).
    -   [x] Delete orphaned mock file `test/features/jobs/data/services/sync_pending_jobs_test.mocks.dart`.

## Code Review Findings (Post-Refactor)

-   **`JobSyncOrchestratorService`:**
    -   Generally follows plan (Phase 2, Step 4).
    -   Dependencies (`LocalDS`, `NetworkInfo`, `ProcessorService`) are correct.
    -   `Mutex` added for concurrency control - good.
    -   Correctly fetches jobs and delegates processing to `JobSyncProcessorService`.
    -   Handles `CacheException` during job fetching gracefully.
    -   [x] **DONE:** Remove the redundant `_calculateExponentialBackoff` helper function. Its logic is duplicated or unnecessary as the core backoff check happens in the `LocalDataSource`.
-   **`JobSyncProcessorService`:**
    -   Follows plan (Phase 2, Step 3).
    -   Dependencies (`LocalDS`, `RemoteDS`, `FileSystem`) are correct.
    -   Methods (`processJobSync`, `processJobDeletion`) and helpers (`_handleRemoteSyncFailure`, `_handleSyncError`, `_permanentlyDeleteJob`) moved and renamed correctly.
    -   Error handling and permanent deletion logic appear solid.
-   **`JobSyncService`:**
    -   Confirmed deleted from staged changes. Good riddance.

-   **Dependency Injection (`injection_container.dart`)**:
    -   Imports updated correctly.
    -   `JobSyncProcessorService` registered correctly.
    -   `JobSyncOrchestratorService` registered correctly.
    -   Old `JobSyncService` registration removed.
    -   [x] **DONE:** Fix `JobRepositoryImpl` registration. It should only inject `JobSyncOrchestratorService`.

-   **`JobRepositoryImpl`**:
    -   Imports updated correctly.
    -   `syncPendingJobs` correctly delegates to `_orchestratorService`.
    -   [x] **DONE:** Remove dependency on `JobSyncProcessorService`. The constructor and fields should only include `JobSyncOrchestratorService`.
    -   [x] **DONE:** Remove the `syncSingleJob` method entirely from the interface and implementation. It bypasses the orchestrator and contradicts the background sync model.

-   **Tests**:
    -   `job_sync_orchestrator_service_test.dart`: Correctly adapted. Focuses on orchestrator responsibilities (fetching, delegating to mocked processor). Verifications look good.
    -   `job_sync_processor_service_test.dart`: Correctly adapted from `sync_single_job_test.dart`. Tests processor logic (API calls, local saves/deletes, file deletes) and error handling thoroughly.
    -   `sync_single_job_test.dart`: Confirmed deleted from staged changes.
    -   `sync_pending_jobs_test.dart`: Confirmed deleted from staged changes.

-   **`JobSyncOrchestratorService Tests`**:
    -   Split into `_sync_test.dart` and `_error_handling_test.dart`. Tests look correct for orchestrator logic (fetch, delegate).
    -   [x] **DONE:** Delete the original combined test file `test/features/jobs/data/services/job_sync_orchestrator_service_test.dart` as it's now redundant.

-   **`JobRepositoryImpl Tests` (`job_repository_impl_test.dart`)**:
    -   Reflects incorrect dependencies: Mocks both orchestrator and processor.
    -   [x] **DONE:** Update mocks and setup to only use `JobSyncOrchestratorService`.
    -   [x] **DONE:** Re-add `syncPendingJobs` test and verify delegation to `mockOrchestratorService`.
    -   [x] **DONE:** Update `verifyZeroInteractions` in other tests after fixing dependencies.
    -   *Note: Test for `syncSingleJob` was correctly absent/removed.*

-   **Integration Test (`job_lifecycle_test.dart`)**:
    -   Mocks updated to use `JobSyncOrchestratorService`.
    -   Verification for `syncPendingJobs` delegation to orchestrator is correct.
    -   **Integration Test (`job_lifecycle_test.dart`)**:
        -   Mocks updated to use `JobSyncOrchestratorService`.
        -   Verification for `syncPendingJobs` delegation to orchestrator is correct.
        -   [x] **DONE:** Instantiation of `JobRepositoryImpl` fixed to reflect corrected repo dependencies.
        -   [x] **DONE:** Remove manually defined `MockJobSyncProcessorService` class.

## Outstanding Tasks

-   [x] **Implement `resetFailedJob`:**
    -   [x] Add `resetFailedJob(String localId)` method to `JobSyncOrchestratorService`.
    -   [x] Implement logic in the orchestrator to fetch the job, check if its status is `SyncStatus.failed`.
    -   [x] If failed, update the job's status to `SyncStatus.pending`, reset `retryCount` to 0, and clear `lastSyncAttemptAt` via `JobLocalDataSource.saveJob`.
    -   [x] Update `JobRepositoryImpl.resetFailedJob` to correctly delegate to the orchestrator method.
    -   [x] Add corresponding tests for `resetFailedJob` in `job_sync_orchestrator_service_test.dart` (success and failure cases, e.g., job not found, job not in failed state).
-   [x] **Update Architecture Document (`feature-job-dataflow.md`):**
    -   [x] Reflect the split of `JobSyncService` into `JobSyncOrchestratorService` and `JobSyncProcessorService` in diagrams and descriptions.
    -   [x] Remove `syncSingleJob` from the `JobRepository` interface definition.
    -   [x] Clarify that backoff eligibility check happens in `LocalDataSource`, while status updates happen in the `ProcessorService`.
    -   [x] Ensure `resetFailedJob` is correctly represented in the repository interface.

## Later Future TODOs

-   [ ] **Enhanced Error Resilience:**
    -   [ ] Add circuit breaker pattern to avoid overwhelming failing servers
    -   [ ] Implement more granular error categorization (temporary vs. permanent failures)
    -   [ ] Create specialized handling for common error cases (auth failures, payload issues)

-   [ ] **User Experience Improvements:**
    -   [ ] Provide more granular sync status indicators in the UI
    -   [ ] Add manual sync trigger capability for individual jobs
    -   [ ] Implement progress indicators for large uploads/downloads
    -   [ ] Allow user configuration of sync frequency and retry policies

-   [ ] **Testing Enhancements:**
    -   [ ] Create comprehensive integration tests simulating various network conditions
    -   [ ] Add property-based testing for sync edge cases
    -   [ ] Implement stress tests for large job volumes
    -   [ ] Add performance benchmarks for sync operationsSince no dictation text was provided after the prompt, I cannot perform any editing. If you would like me to edit a dictation transcript, please provide the actual text. 

## Much Later (if, as we'll have 50-100 jobs max at any given time)

-   [ ] **Sync Process Observability:**
    -   [ ] Add detailed metrics collection (sync success rate, latency, error distribution)
    -   [ ] Implement a sync status dashboard for debugging and monitoring
    -   [ ] Create an audit log of all sync operations for troubleshooting

-   [ ] **Performance Optimization for Bulk Operations:**
    -   [ ] Implement batch processing for multiple jobs with the same sync status
    -   [ ] Add concurrency control for parallel job processing with configurable limits
    -   [ ] Optimize database queries by reducing redundant reads/writes during sync
