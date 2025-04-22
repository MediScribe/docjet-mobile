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
- [ ] Postpone (YAGNI Alert): Add retry mechanism for failed file deletions on next app startup

## 4. Prepare UI Notifications for File System Issues
Implement a mechanism to inform users when file cleanup operations fail. Do not implement the actual UI; instead come up with a best practice way allow the UI to respond.

- [ ] Add `failedAudioDeletionAttempts` counter to `Job` entity:
  - [ ] Update `Job` class in domain layer
  - [ ] Update `JobHiveModel` in data layer
  - [ ] Update mappers between domain and data models
  - [ ] Ensure `copyWith` methods include the new field
- [ ] Enhance deletion error handlers to update counter:
  - [ ] In `JobDeleterService`, increment counter on file deletion failure
  - [ ] In `JobSyncProcessorService`, increment counter on file deletion failure
  - [ ] Save updated job after incrementing counter
- [ ] Expose file issue information to UI:
  - [ ] Add file issue indicator to job list items in UI
  - [ ] Add more detailed error information to job detail screen
  - [ ] Consider adding a "Retry Cleanup" action in UI
- [ ] Add ability to manually reset counter when cleanup succeeds
- [ ] Document the file issue notification architecture in `job_dataflow.md`

## 5. Data Flow Architecture Verification
Verify our stream-based architecture is fully implemented for reactive UI updates.

- [ ] Confirm `HiveJobLocalDataSourceImpl` implements `box.watch()` properly
- [ ] Verify `JobRepositoryImpl` exposes streams via:
  - [ ] `Stream<List<Job>> watchJobs()` method
  - [ ] `Stream<Job?> watchJobById(String localId)` method
- [ ] Create use cases for streams if not already done:
  - [ ] `WatchJobsUseCase` that returns `Stream<List<Job>>`
  - [ ] `WatchJobByIdUseCase` that returns `Stream<Job?>`
- [ ] Ensure presentation layer consumes streams properly:
  - [ ] Verify BLoC/Cubit subscribes to job streams
  - [ ] Verify UI uses `StreamBuilder` for reactive rendering
  - [ ] Test that UI updates automatically when job sync status changes

## 6. Testing Additions
Enhance test coverage for sync edge cases.

- [ ] Write tests for file deletion error handling
- [ ] Write tests for exponential backoff calculations
- [ ] Write tests for mutex lock behavior
- [ ] Write tests for stream propagation of sync status changes
- [ ] Add specific UI tests for file issue indicator display 