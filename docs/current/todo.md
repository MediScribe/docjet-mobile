# DocJet Mobile: Job Sync Architecture Hardening

**Reference Documents:**
- [Overall Architecture](docs/current/architecture.md)
- [Job Data Flow](docs/current/job_dataflow.md)
- [Authentication Architecture](docs/current/auth_architecture.md)

## 1. Mutex Implementation Verification
Make sure our mutex implementation is robust across concurrent sync attempts from different sources.

- [X] Verify mutex implementation in `JobSyncOrchestratorService` is using `package:mutex` Lock (Default is re-entrant)
- [X] Explicitly document that we're using re-entrant lock mechanism (Added comment in code)
- [X] Add unit test that verifies lock behavior under concurrent access (foreground/background collision) (Test exists: `should handle concurrent sync calls using the lock`)
- [X] Update `job_dataflow.md` to explicitly mention re-entrancy of mutex implementation
- [X] Verify lock is properly released on all function exit paths (including exceptions)

## 2. Exponential Backoff Parameters
Document and review our retry strategy configuration parameters.

- [X] Document the `baseBackoff` value in `job_dataflow.md` (currently missing)
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
- [ ] Postponed: Expose file issue information to UI:
  - [ ] Add file issue indicator to job list items in UI
  - [ ] Add more detailed error information to job detail screen
  - [ ] Consider adding a "Retry Cleanup" action in UI
- [X] Add ability to manually reset counter when cleanup succeeds
- [X] Document the file issue notification architecture in `job_dataflow.md`

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
- [ ] Add specific UI tests for file issue indicator display 

## 7. Follow-up Code Improvements
Additional improvements identified during code review.

- [ ] Standardize error logging approach (use `logError` helper consistently instead of direct `_logger.e` calls)
- [ ] Add defensive coding for counter increments (null checks before incrementing `failedAudioDeletionAttempts`)
- [ ] Consider extracting nested try-catch blocks into helper methods in `JobDeleterService` for better readability
- [X] Move all config values (retry backoff times, max attempts) to a dedicated config class
- [ ] Document thread-safety guarantees for all services that handle file operations
- [ ] Add dedicated helper method to reset the `failedAudioDeletionAttempts` counter 