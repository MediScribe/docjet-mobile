# Job Sync Service Refactoring Plan

This document outlines the steps to refactor the monolithic `JobSyncService` into a more manageable structure with an `Orchestrator` and a `Processor`.

## TODO List - Hard Bob Style

### Phase 1: Internal Refactoring (No new files yet)

-   [ ] **1. Isolate `syncSingleJob` Failure Logic:**
    -   [ ] Create private helper `_handleRemoteSyncFailure(Job job, dynamic error)` in `JobSyncService`.
    -   [ ] Move `catch` block logic from `syncSingleJob` into the helper.
    -   [ ] Update `syncSingleJob` to call the helper.
    -   [ ] Run `flutter test test/features/jobs/data/services/sync_single_job_test.dart` (must pass).

-   [ ] **2. Isolate `syncPendingJobs` Deletion Logic:**
    -   [ ] Create private helper `_processSingleDeletion(Job jobToDelete)` in `JobSyncService`.
    -   [ ] Move deletion loop logic (API call, try/catch, `_permanentlyDeleteJob` call) into the helper.
    -   [ ] Update `syncPendingJobs` to call the helper within the loop.
    -   [ ] Run `flutter test test/features/jobs/data/services/sync_pending_jobs_test.dart` (must pass).

### Phase 2: Splitting the Service

-   [ ] **3. Create `JobSyncProcessorService`:**
    -   [ ] Create `lib/features/jobs/data/services/job_sync_processor_service.dart`.
    -   [ ] Define `JobSyncProcessorService` class.
    *   [ ] Move `syncSingleJob` (rename to `processJobSync`) to `JobSyncProcessorService`.
    *   [ ] Move `_processSingleDeletion` (rename to `processJobDeletion`) to `JobSyncProcessorService`.
    *   [ ] Move `_handleRemoteSyncFailure` (make private) to `JobSyncProcessorService`.
    *   [ ] Move `_handleSyncError` (make private) to `JobSyncProcessorService`.
    *   [ ] Move `_permanentlyDeleteJob` (make private) to `JobSyncProcessorService`.
    *   [ ] Define dependencies: `JobLocalDataSource`, `JobRemoteDataSource`, `FileSystem`.

-   [ ] **4. Refactor `JobSyncService` into `JobSyncOrchestratorService`:**
    -   [ ] Rename `JobSyncService` class and file to `JobSyncOrchestratorService`.
    -   [ ] Update dependencies: Include `NetworkInfo`, `JobLocalDataSource`, `JobSyncProcessorService`. Remove `JobRemoteDataSource`, `FileSystem`.
    -   [ ] Modify `syncPendingJobs` to call `_processorService.processJobSync(job)`.
    -   [ ] Modify `syncPendingJobs` to call `_processorService.processJobDeletion(job)`.
    -   [ ] Remove unused methods (`syncSingleJob`, `_processSingleDeletion`, helpers) from orchestrator.

-   [ ] **5. Update Dependency Injection:**
    -   [ ] Register `JobSyncProcessorService` in DI container.
    -   [ ] Update registration for `JobSyncOrchestratorService` with new dependencies.
    -   [ ] Verify DI setup manually.

### Phase 3: Splitting the Tests

-   [ ] **6. Create `job_sync_processor_service_test.dart`:**
    -   [ ] Copy `sync_single_job_test.dart` to `job_sync_processor_service_test.dart`.
    -   [ ] Update `main`, imports, mocks (`LocalDS`, `RemoteDS`, `FileSystem`), and tested class (`JobSyncProcessorService`).
    -   [ ] Rename test groups/descriptions (`syncSingleJob` -> `processJobSync`).
    -   [ ] Add tests for `processJobDeletion` (success/failure paths).
    -   [ ] Run `flutter test test/features/jobs/data/services/job_sync_processor_service_test.dart` (must pass).

-   [ ] **7. Refactor `sync_pending_jobs_test.dart` to `job_sync_orchestrator_service_test.dart`:**
    -   [ ] Rename `sync_pending_jobs_test.dart` file and update `main`, imports, tested class (`JobSyncOrchestratorService`).
    -   [ ] Update mocks: Remove `RemoteDS`, `FileSystem`. Add mock for `JobSyncProcessorService`.
    -   [ ] Update arrangements/verifications: Verify calls to mocked `_processorService.processJobSync` and `_processorService.processJobDeletion`.
    -   [ ] Run `flutter test test/features/jobs/data/services/job_sync_orchestrator_service_test.dart` (must pass).

-   [ ] **8. Delete Old Test File:**
    -   [ ] Delete `test/features/jobs/data/services/sync_single_job_test.dart`.
    -   [ ] Run `flutter test lib/features/jobs/data/services/` (all tests must pass). 