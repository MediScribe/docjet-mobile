# DocJet Mobile: Job Sync Architecture Hardening

**Reference Documents:**
- [Overall Architecture](docs/current/architecture.md)
- [Job Data Flow](docs/current/feature-job-dataflow.md)
- [Authentication Architecture](docs/current/feature-auth-architecture.md)
- [Authentication Implementation Details](docs/current/feature-auth-implementation.md)

## 1. Mutex Implementation Verification
Make sure our mutex implementation is robust across concurrent sync attempts from different sources.

- [X] Verify mutex implementation in `JobSyncOrchestratorService` is using `package:mutex` Lock (Default is re-entrant)
- [X] Explicitly document that we're using re-entrant lock mechanism (Added comment in code)
- [X] Test mutex lock behaviour in `JobSyncOrchestratorService` to ensure only one sync runs at a time
- [X] Update `feature-job-dataflow.md` to explicitly mention re-entrancy of mutex implementation
- [X] Verify lock is properly released on all function exit paths (including exceptions)

## 2. Exponential Backoff Parameters
Document and review our retry strategy configuration parameters.

- [X] Document the `baseBackoff` value in `feature-job-dataflow.md` (currently missing)
- [X] Extract retry constants to a configuration class instead of hardcoded values:
  - [X] Create `JobSyncConfig` class with constants
  - [X] Move `MAX_RETRY_ATTEMPTS` (currently 5) into config
  - [X] Move `baseBackoff` duration into config
  - [X] Add `maxBackoff` cap to prevent excessive wait times
- [X] Update retry backoff calculation math to include cap: `min(baseBackoff * pow(2, retryCount), maxBackoff)`
- [X] Add comments in code explaining the exponential backoff formula with examples

## 3. Audio File Deletion Error Handling
Improve handling of audio file deletion failures with robust logging and recovery.

- [X] Audit all file deletion points in code:
  - [X] `JobDeleterService.deleteJob` (local-initiated deletion) - *Note: Does not delete files, only marks status.*
  - [X] `JobDeleterService.permanentlyDeleteJob` - *Deletes DB record & file; file errors logged as warning.*
  - [X] `JobSyncProcessorService._permanentlyDeleteJob` (server-confirmed deletion) - *Deletes DB record & file; file errors logged as warning.*
  - [X] Any other places files are deleted - *Audit suggests these are the primary points.*
- [X] Implement thorough structured logging for file deletion failures:
  - [X] Use `log_helpers.dart` facility instead of print statements
  - [X] Include job `localId` in all log entries
  - [X] Include full file path in log entries
  - [X] Include specific exception/error message in log entries
  - [X] Add log severity level (ERROR)
- [X] Verify try-catch blocks around all file operations
- [X] Verify path normalization and null-checking before deletion attempts
- [X] Postpone (YAGNI Alert): Add retry mechanism for failed file deletions on next app startup

## 4. Prepare UI Notifications for File System Issues
Implement a mechanism to inform users when file cleanup operations fail. Do not implement the actual UI; instead come up with a best practice way allow the UI to respond.

- [X] Add `failedAudioDeletionAttempts` counter to `Job` entity:
  - [X] Update `Job` class in domain layer
  - [X] Update `JobHiveModel` in data layer
  - [X] Update mappers between domain and data models
  - [X] Ensure `copyWith` methods include the new field
- [X] Enhance deletion error handlers to update counter:
  - [X] In `JobDeleterService`, increment counter on file deletion failure
  - [X] In `JobSyncProcessorService`, increment counter on file deletion failure
  - [X] Save updated job after incrementing counter
- [X] Prepare Presentation Layer (UI-Independent Foundation):
  - [X] Create `JobViewModel` and mapper in `lib/features/jobs/presentation/mappers/`
  - [X] Define `JobListState` and `JobDetailState` classes
  - [X] Implement `JobListCubit` (subscribes to `WatchJobsUseCase`)
  - [X] Implement `JobDetailCubit` (subscribes to `WatchJobByIdUseCase`)
  - [X] Register cubits in DI module (`JobsModule.registerPresentation`)
  - [X] Write unit tests for `JobListCubit`
  - [X] Write unit tests for `JobDetailCubit`
  - [X] Document presentation layer prep in `job_presentation_layer.md` (New doc)
- [X] Add ability to manually reset counter when cleanup succeeds
- [X] Document the file issue notification architecture in `feature-job-dataflow.md`

## 5. Data Flow Architecture Verification
Verify our stream-based architecture is fully implemented for reactive UI updates.

- [X] Confirm `HiveJobLocalDataSourceImpl` implements `box.watch()` properly
- [X] Verify `JobRepositoryImpl` exposes streams via:
  - [X] `Stream<List<Job>> watchJobs()` method
  - [X] `Stream<Job?> watchJobById(String localId)` method
- [X] Create use cases for streams if not already done:
  - [X] `WatchJobsUseCase` that returns `Stream<List<Job>>`
  - [X] `WatchJobByIdUseCase` that returns `Stream<Job?>`
- [X] PREPARE without building the UI itself (refer to the user to discuss!):
      Ensure presentation layer consumes streams properly:
  - [X] Write integration tests for `WatchJobsUseCase` and `WatchJobByIdUseCase` to verify stream emissions upon data changes.
  - [X] Ensure these tests cover scenarios like job creation, updates, and sync status changes triggering stream updates.
  - [X] Remove vague checks: ~~Verify BLoC/Cubit subscribes to job streams~~
  - [X] Remove vague checks: ~~Verify UI uses StreamBuilder for reactive rendering~~
  - [X] Remove vague checks: ~~Test that UI updates automatically when job sync status changes~~

## 6. Testing Additions
Enhance test coverage for sync edge cases.

- [X] Write tests for file deletion error handling
- [X] Write tests for exponential backoff calculations
- [X] Write tests for stream propagation of sync status changes (Covered by Use Case tests above)
- [X] Add specific UI tests for file issue indicator display:
    - **Goal:** Verify the UI correctly shows a warning indicator (e.g., the orange `Icons.warning_amber_rounded` in `JobListItem`) when a `JobViewModel` has `hasFileIssue == true`.
    - **Where:** Add tests to `test/features/jobs/presentation/pages/job_list_page_test.dart`.
    - **How:**
        - Create a `MockJobListCubit` that emits a `JobListLoaded` state.
        - Include at least one `JobViewModel` in the state with `hasFileIssue: true` and another with `hasFileIssue: false`.
        - Use `WidgetTester` to pump the `JobListPage`.
        - Use `find.byIcon(Icons.warning_amber_rounded)` to verify the warning icon appears for the correct job item.
        - Use `find.byIcon(Icons.article_outlined)` to verify the standard icon appears for the job item without the issue.
        - Ensure no warning icon appears for the job without the issue.

## 7. Follow-up Code Improvements
Additional improvements identified during code review.

- [X] Add defensive coding for counter increments (null checks before incrementing `failedAudioDeletionAttempts`)
- [ ] Consider extracting nested try-catch blocks into helper methods in `JobDeleterService` for better readability:
    - **Goal:** Improve clarity and reduce nesting in `JobDeleterService` methods handling file deletions (e.g., `permanentlyDeleteJob`).
    - **Where:** Examine `lib/features/jobs/data/services/job_deleter_service.dart`.
    - **How:**
        - Identify methods with nested `try-catch` for file operations.
        - Create a private helper (e.g., `_safelyDeleteFile(String? filePath, String jobIdForLogging)`) encapsulating the file deletion `try-catch` and logging.
        - Refactor original methods to call the helper.
    - **Decision:** Evaluate if extraction genuinely improves readability. If not, document decision and mark N/A.
- [X] Move all config values (retry backoff times, max attempts) to a dedicated config class
- [X] Document thread-safety guarantees for all services that handle file operations:
    - **Goal:** Explicitly state concurrency guarantees for services interacting with the file system.
    - **Where:** Add doc comments (`///`) to relevant service classes (`JobDeleterService`, `JobSyncProcessorService`, etc.).
    - **How:** Add a `## Thread Safety` section explaining they are designed for single-isolate use unless otherwise noted, and external synchronization (like mutexes) is needed for multi-isolate access.
- [X] Add dedicated helper method to reset the `failedAudioDeletionAttempts` counter:
    - **Goal:** Provide a clean way to reset the failure counter back to zero.
    - **Where:** Implement in `JobWriterService`.
    - **How:**
        - [X] Define `Future<Either<Failure, Job>> resetDeletionFailureCounter(String localId)` in `JobWriterService`.
        - [X] Fetch job, check if counter > 0, update using `job.copyWith(failedAudioDeletionAttempts: 0)`, save, return `Right(updatedJob)`. Keep existing `syncStatus`.
        - [X] Create corresponding `ResetDeletionFailureCounterUseCase`.
        - [X] Add unit tests for the service method and use case.

## 8. UI Implementation (TDD)

### 8.1 JobListPage
- [X] TDD: Implement `JobListLoading` state display (Show `CircularProgressIndicator`)
- [X] TDD: Implement `JobListLoaded` state (Empty List) display (Show "No jobs yet." message)
- [X] TDD: Implement `JobListLoaded` state (Populated List) display (Show basic `ListView` with titles)
- [X] TDD: Implement `JobListError` state display (Show error message)
- [X] Refactor: Implement `JobViewModel` and mapper
- [X] Refactor: Replace placeholders (`List<dynamic>`, `MockJobViewModel`) in state/tests
- [X] Refactor: Create and integrate dedicated `JobListItem` widget
- [X] Implement `JobListCubit` logic (inject `WatchJobsUseCase`, subscribe to stream)
- [X] TDD: Add tests for `JobListCubit` stream listening logic

## 9. Post-Code-Review Cleanup
- [X] Renumber steps in `.cursor/rules/hard-bob-workflow.mdc`:
    - Open the file and remove duplicate numbering (e.g., the second "2." for GREP First).
    - Reorder list so items count from 1 through the last without gaps or repeats.
    - Save and verify numbering consistency.
- [X] Ensure trailing newline at EOF for all modified files:
    - For each changed .md and .dart file, open and add exactly one blank line at the end.
    - Run `git diff` to confirm no missing EOF newline warnings.
- [X] Remove duplicate cubit directory and stub file:
    - Delete `lib/features/jobs/presentation/cubits/job_list_cubit.dart` (the empty stub).
    - Confirm only one `job_list_cubit.dart` remains under the chosen folder (either `cubit/` or `cubits/`).
- [X] Consolidate `state` vs `states` directories and fix imports:
    - Delete the unused `lib/features/jobs/presentation/state/` folder entirely.
    - Keep `lib/features/jobs/presentation/states/` as the single source of truth for state classes.
    - Update all imports in presentation code and tests from `.../state/...` to `.../states/...`.
- [X] Decide on and implement one `JobListState` pattern:
    - **Option A**: Union-style with Freezed (variants: `initial`, `loading`, `loaded`, `error`).
      * Create a Freezed `job_list_state.dart`, run code generation, emit state variants in cubit.
- [X] Remove commented-out legacy code:
    - In the remaining `job_list_cubit.dart`, remove the entire commented `loadJobs()` block.
- [X] Clean up dead code and enforce one-class-per-file:
    - Remove any remaining empty or unused stub files in `presentation/`.
    - Confirm each Dart file defines exactly one public class.
- [X] Update tests to match the refactored API:
    - In `test/features/jobs/presentation/cubit/job_list_cubit_test.dart`, adjust `blocTest` expectations to use real state classes or `copyWith` calls.
    - Remove tests that assumed `JobListState.initial().copyWith(...)` if not using that pattern.
- [X] Run static analysis and formatting:
    - Execute `dart analyze` and fix all reported issues.
    - Execute `dart format .` to apply consistent formatting.

## 10. Deep Code Review Corrections
- [X] Revert manual edits to generated files (`job_api_dto.g.dart`, `job_detail_state.freezed.dart`) and regenerate with build_runner.
    - **Action:** Run `git restore lib/features/jobs/data/models/job_api_dto.g.dart`
    - **Action:** Run `git restore lib/features/jobs/presentation/states/job_detail_state.freezed.dart`
    - **Action:** Run `dart run build_runner build --delete-conflicting-outputs`
    - **Action:** Stage the *newly generated* versions of both files.
- [X] Fix missing logger declarations (`_logger`, `_tag`) in `JobListPage` and related widgets.
    - **Note:** `JobListPage` and `JobListItem` *do* have loggers staged. This item specifically refers to the Cubits.
    - **Action:** Add standard logger setup (`static final Logger _logger = ...`, `static final String _tag = ...`) to `lib/features/jobs/presentation/cubit/job_list_cubit.dart`.
    - **Action:** Add standard logger setup to `lib/features/jobs/presentation/cubit/job_detail_cubit.dart`.
    - **Action:** Integrate logging calls (e.g., `_logger.d('$_tag ...')`) within the methods of both Cubits.
    - **Action:** Stage the modified Cubit files.
- [X] Remove commented-out dead code (e.g., old `loadJobs()` method and FAB code).
    - **Note:** Old `loadJobs` in `JobListCubit` *is* removed in staged changes. FAB in `JobListPage` is commented but noted.
    - **Action:** Remove the commented FAB code in `lib/features/jobs/presentation/pages/job_list_page.dart` permanently.
- [X] Override `close()` in `JobListCubit` and `JobDetailCubit` to properly cancel the `_jobSubscription`.
    - **Action:** Add the `@override Future<void> close() { _jobSubscription?.cancel(); return super.close(); }` method to `lib/features/jobs/presentation/cubit/job_list_cubit.dart`.
    - **Action:** Add the same `close()` method override to `lib/features/jobs/presentation/cubit/job_detail_cubit.dart`.
    - **Action:** Stage the modified Cubit files.
- [X] Register `JobListCubit` and `JobDetailCubit` in the DI container (`injection_container.dart`).
    - **Note:** The import path change *is* staged in `injection_container.dart`.
    - **Action:** Register JobListCubit in `lib/core/di/injection_container.dart`. Ensure WatchJobsUseCase and JobViewModelMapper are also registered.
    - **Action:** Stage the modified DI container file.
- [X] Unify state-pattern for both list and detail (`JobListState`/`JobDetailState`) using the chosen approach (Freezed or hand-rolled).
    - **Note:** New state files *are* staged, and Cubits reference them.
    - **Action:** Update `JobListState` to remove TODO comment about JobViewModel.
    - **Action:** Stage the modified state files.

## 11. API Versioning Centralization

Implement a centralized approach to API versioning to simplify future version changes.

- [X] Create ApiConfig Test:
  - [X] Write test that ApiConfig provides correct endpoints with version prefix
  - [X] Test baseUrlFromDomain constructs URLs correctly 
  - [X] Test all endpoint methods return unprefixed paths
- [X] Build ApiConfig Class:
  - [X] Create `lib/core/config/api_config.dart` with apiVersion constant 
  - [X] Implement baseUrlFromDomain method
  - [X] Implement all endpoint getter methods (unprefixed)
- [X] Update Environment Config:
  - [X] Remove version from API_BASE_URL in secrets files
  - [X] Update to API_DOMAIN format in all secrets files
- [X] Update Dio Factory:
  - [X] Modify baseUrl construction to use ApiConfig
  - [X] Ensure all environments use consistent URL construction
- [X] Update E2E Test Setup:
  - [X] Modify baseUrl construction in e2e_setup_helpers.dart
  - [X] Ensure mock server uses consistent URL format
- [X] Update Shell Scripts:
  - [X] Update server URL construction in run_with_mock.sh
  - [X] Update server URL construction in run_e2e_tests.sh
- [X] Update Mock Server:
  - [X] Add apiVersion constant to match ApiConfig
  - [X] Use consistent prefix for all route definitions
- [X] Final E2E Tests:
  - [X] Run integration tests to verify all endpoints work
  - [X] Validate setup for testing version changes
- [X] Document Versioning Approach:
  - [X] Add api_versioning.md explaining the architecture
  - [X] Include version change procedure for future reference

## 12. Post-Code-Review Cleanup (Round 2)

Address items identified during the latest code review:

- [X] `JobDeleterService`:
    - [X] Refactor logger instantiation to use `LoggerFactory.getLogger(JobDeleterService)`.
    - [X] Add unit tests for the `_safelyDeleteFileAndHandleFailure` helper method covering:
        - [X] Success path (file deleted, counter unchanged).
        - [X] File deletion failure path (counter incremented, save succeeds).
        - [X] File deletion failure + save failure path (error logged, no crash).
    - [X] Include `stackTrace` in the `catch (saveError, st)` block within `_safelyDeleteFileAndHandleFailure`.
    - [X] Remove or clarify the "Defensive check" comment regarding the non-nullable `failedAudioDeletionAttempts`.
- [X] `JobSyncProcessorService`:
    - [X] Add `static final String _tag = logTag(JobSyncProcessorService);`.
    - [X] Prefix all `_logger` calls with `$_tag`.
    - [X] Remove unused import for `job_sync_logger.dart`.
- [X] `JobWriterService`:
    - [X] Implement logging in `catch` blocks (remove `// TODO:` comments). Use `LoggerFactory` and `_tag`.
    - [X] Reflow Dartdoc comments for `resetDeletionFailureCounter` to < 80 chars.
- [X] `job_writer_service_test.dart`:
    - [X] Shorten lengthy `test(...)` descriptions for conciseness.

