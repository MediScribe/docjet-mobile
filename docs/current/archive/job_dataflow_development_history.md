# Job Data Layer Development History

This document captures the historical development process and implementation notes for the Job feature in DocJet Mobile. For the current architecture and data flow, see [job_dataflow.md](./job_dataflow.md).

## Implementation Status & TODOs (Historical)

### Implemented Components
- ✅ Job Entity (lib/features/jobs/domain/entities/job.dart)
- ✅ JobRepository Interface (lib/features/jobs/domain/repositories/job_repository.dart)
- ✅ JobLocalDataSource Interface (lib/features/jobs/data/datasources/job_local_data_source.dart)
- ✅ HiveJobLocalDataSourceImpl (lib/features/jobs/data/datasources/hive_job_local_data_source_impl.dart)
- ✅ JobHiveModel (lib/features/jobs/data/models/job_hive_model.dart)
- ✅ JobRemoteDataSource Interface (lib/features/jobs/data/datasources/job_remote_data_source.dart)
- ✅ ApiJobRemoteDataSourceImpl (lib/features/jobs/data/datasources/api_job_remote_data_source_impl.dart)
- ✅ Basic JobMapper (for Hive models only) (lib/features/jobs/data/mappers/job_mapper.dart)
- ✅ JobApiDTO (lib/features/jobs/data/models/job_api_dto.dart)
- ✅ SyncStatus enum (lib/features/jobs/domain/entities/sync_status.dart)
- ✅ **COMPLETED** - Server-side deletion detection

### TODO Components
- ✅ **EXISTING NEEDS UPDATE** - JobRepositoryImpl (lib/features/jobs/data/repositories/job_repository_impl.dart)
  - File exists but needs enhancement
  - ⚠️ **IN PROGRESS** - Implement `syncPendingJobs` using the defined Sync Strategy.
  - Add support for syncing pending jobs when connectivity is restored (Trigger mechanism TBD)

- ✅ **COMPLETED** - Extend JobMapper with API DTO support (lib/features/jobs/data/mappers/job_mapper.dart)
  - Implemented `fromApiDto` and `toApiDto`
  - Implemented `fromApiDtoList`
  - ✅ **COMPLETED** - Skipped `toApiDtoList` as likely not needed for batch updates

- ✅ **COMPLETED** - Implement JobStatus enum for type-safe status handling
  - ✅ **COMPLETED** - Create `JobStatus` enum in domain layer
  - ✅ **COMPLETED** - Update `Job`, `JobHiveModel`, and `JobApiDTO` to use the enum
  - ✅ **COMPLETED** - Update `JobMapper` to handle conversion between different status formats
  - ✅ **COMPLETED** - Update any business logic that depends on job status

- ❌ **LOW PRIORITY** - Pagination support in RemoteDataSource
  - Add pagination parameters to API calls
  - Implement pagination state tracking

- ❌ **LOW PRIORITY** - Network connectivity detection
  - Add network state detection before API calls
  - Implement offline-first behavior

### Implementation Notes
- ApiJobRemoteDataSourceImpl currently maps JSON directly to Job entities in _mapJsonToJob
- No freshness policy is implemented yet (deciding when local data is stale)
- No explicit error recovery strategy implemented for network failures
- ✅ **COMPLETED** - Added SyncStatus enum tracking to JobHiveModel
- ✅ **COMPLETED** - Implemented getJobsToSync and updateJobSyncStatus methods in JobLocalDataSource

### Current Implementation Progress

✅ **COMPLETED** - The latest implementation adds support for sync status tracking and timestamp handling:

1. ✅ **COMPLETED** - Updated `JobLocalDataSource` interface to include timestamp methods:
   - Added `Future<DateTime?> getLastFetchTime();` - Returns when data was last fetched from remote
   - Added `Future<void> saveLastFetchTime(DateTime time);` - Records when data was fetched

2. ✅ **COMPLETED** - Implemented these methods in `HiveJobLocalDataSourceImpl`:
   - Store fetch timestamp in Hive using a dedicated key
   - Handle null cases and type errors for first-time access
   - Ensure UTC consistency in timestamp handling

3. ✅ **COMPLETED** - Added support for sync status tracking:
   - Created SyncStatus enum (pending/synced/error)
   - Extended JobHiveModel with syncStatus field
   - Added getJobsToSync and updateJobSyncStatus methods to JobLocalDataSource
   - Implemented methods in HiveJobLocalDataSourceImpl with robust error handling

## TDD Implementation Plan

This bottom-up implementation plan follows Test-Driven Development principles, focusing on isolated components first.

### Level 1: Zero Dependencies (Isolated Components)

1. ✅ **COMPLETED** - Add `uuid` package:
   - RED: Write test verifying UUID generation works
   - GREEN: Add package to pubspec.yaml, run pub get
   - REFACTOR: Ensure tests are clean and meaningful

2. ✅ **COMPLETED** - Use existing FileSystem service:
   - RED: Write tests verifying FileSystem interaction
   - GREEN: Ensure we can use the existing implementation
   - REFACTOR: Clean up tests

3. ✅ **COMPLETED** - Update `SyncStatus` enum:
   - RED: Write tests expecting the new `pendingDeletion` value
   - GREEN: Add the value to enum, run code generation
   - REFACTOR: Ensure enum has clear documentation

### Level 2: Basic Models

4. ✅ **COMPLETED** - Update `JobEntity` and `JobHiveModel`:
   - RED: Write tests for dual-ID support (`localId` and `serverId`)
   - GREEN: Add fields, run code generation
   - REFACTOR: Ensure good default values

5. ✅ **COMPLETED** - Update `JobMapper`:
   - RED: Write tests for mapping between dual-ID models
   - GREEN: Update mapper implementation
   - REFACTOR: Ensure consistent mapping

### Level 3: DataSource Layer

6. ✅ **COMPLETED** - Update `JobLocalDataSource` interface:
   - RED: Write tests for new methods (getSyncedJobs, deleteJob)
   - GREEN: Add interface methods
   - REFACTOR: Ensure clear documentation

7. ✅ **COMPLETED** - Update `HiveJobLocalDataSourceImpl`:
   - RED: Write tests for implementation of new methods
   - GREEN: Implement methods
   - REFACTOR: Ensure robust error handling

### Level 4: Repository Layer

8. ✅ **COMPLETED** - Update `JobRepositoryImpl` constructor:
   - RED: Write tests expecting FileSystem dependency
   - GREEN: Add parameter to constructor
   - REFACTOR: Ensure defaults for backward compatibility

9. ✅ **COMPLETED** - Implement `createJob` method:
   - RED: Write tests covering UUID generation, status setting
   - GREEN: Implement method
   - REFACTOR: Ensure proper error handling

10. ✅ **COMPLETED** - Implement `updateJob` method:
    - RED: Write tests for proper status updates
    - GREEN: Implement method
    - REFACTOR: Clean up implementation

11. ✅ **COMPLETED** - Implement `deleteJob` method:
    - RED: Write tests for setting pendingDeletion status
    - GREEN: Implement method to mark jobs for deletion locally
    - REFACTOR: Ensure clean error handling

12. ✅ **COMPLETED** - Update `syncPendingJobs` method:
    - RED: Write tests for all sync scenarios (new/update/delete) using dual-ID system
    - GREEN: Implement logic for each case
    - REFACTOR: Extract common code into helper methods

13. ✅ **COMPLETED** - Add server-side deletion detection to `getJobs`:
    - RED: Write tests for comparing server vs local data
    - GREEN: Implement detection and deletion logic
    - REFACTOR: Ensure clean error handling

14. ✅ **COMPLETED** - Implement test file for deleteJob functionality:
    - Write unit tests for `test/features/jobs/data/repositories/job_repository_impl/delete_job_test.dart`
    - Test all scenarios (delete synced job, delete unsynced job, handle errors)
    - Validate proper status setting logic for marked deletions

### Level 5: Integration Testing

15. ✅ **COMPLETED** - Implement integration tests for Job Repository:
    - Tests implemented in `test/features/jobs/integration/job_lifecycle_test.dart` using mocks for dependencies (`JobLocalDataSource`, `JobRemoteDataSource`, `FileSystem`, `Uuid`).
    - Verified core lifecycle scenarios:
        - ✅ Create → Sync → Update → Sync → Delete → Sync
        - ✅ Batch operations with mixed states (New, Update, Delete)
        - ✅ Server-side deletion detection
        - ✅ Error handling (Network, API, File System failures), including successful retries after failure.
    - Confirmed repository correctly orchestrates calls to data sources and file system based on job state and API responses.

## Implementation Notes (April 2023)

During our implementation of the job synchronization system, we made several key architecture decisions:

1. **Individual Job Synchronization**: Instead of using a batch sync approach, we now process jobs individually with clear operation paths for:
   - Creating new jobs (serverId == null)
   - Updating existing jobs (serverId != null)
   - Deleting jobs (syncStatus == pendingDeletion)

2. **Audio File Cleanup**: We've integrated the FileSystem service to properly manage audio file resources:
   - When a job is deleted (either locally or server-initiated), its audio file is also deleted
   - The file deletion errors are logged but non-fatal to allow sync to proceed

3. **Error Handling**: We've improved error handling with:
   - Per-job error state tracking
   - Graceful failure that doesn't abort the entire sync process
   - Detailed logging for all sync operations

4. **Dual-ID System**: We've fully implemented the dual-ID approach:
   - localId: Client-generated UUID that never changes
   - serverId: Server-assigned ID after first successful sync

5. **Sync Status Tracking**: We've updated our sync status enum to properly track:
   - pending: Local changes awaiting sync
   - synced: Successfully synchronized with server
   - error: Sync failed for this job
   - pendingDeletion: Marked for deletion on next sync

6. **Server-side Deletion Detection**: We've implemented the logic to detect jobs deleted on the server:
   - When fetching from remote, we compare server IDs with locally synced jobs
   - Jobs that exist locally (with synced status) but aren't returned by the server are deleted
   - We properly ignore pending jobs during this check to prevent data loss

7. **Delete Job Implementation**: We've completed the local deletion marking functionality:
   - Jobs are marked with syncStatus.pendingDeletion instead of being immediately deleted
   - This enables offline-first deletion with eventual consistency
   - The actual deletion happens during the sync process for both local and remote persistence
   - Both synced (with serverId) and unsynced jobs are handled correctly

All tests are now passing for this Job feature, including comprehensive test coverage for the delete functionality and repository integration tests.

## Integration Test Plan (May 2023) - Status: COMPLETED

Integration tests verifying the complete job feature functionality **have been implemented and are passing**. These tests ensure that all components orchestrated by the `JobRepositoryImpl` interact correctly through the full job lifecycle.

### Test File Structure

Tests are implemented in `test/features/jobs/integration/job_lifecycle_test.dart`.

### Test Scenarios Covered

The implemented tests cover the following key scenarios using mocked dependencies:

#### Happy Path Tests

1.  ✅ **Complete Job Lifecycle**: Verified the full workflow from creation to deletion, including sync steps.
2.  ✅ **Batch Job Operations**: Verified handling of multiple jobs with different sync states (new, updated, deleted) within a single sync cycle.
3.  ✅ **Server-side Deletion Detection**: Verified the system's ability to detect and handle jobs deleted on the server during a fetch operation.

#### Error Path Tests

4.  ✅ **Network Failures**: Verified graceful handling of connectivity issues, including marking jobs as `error` and successfully retrying them on subsequent sync attempts.
5.  ✅ **API Errors**: Verified proper handling of server errors, marking jobs as `error`.
6.  ✅ **File System Errors**: Verified graceful handling of file system issues during deletion (errors logged, job deletion proceeds).

### Implementation Strategy Used

The integration tests utilize `mockito` to configure mocks for `JobLocalDataSource`, `JobRemoteDataSource`, `FileSystem`, and `Uuid`. These mocks simulate realistic behavior, including state persistence for the local data source and error conditions for the remote data source and file system.

This approach allowed for controlled testing conditions, validating that the `JobRepositoryImpl` correctly orchestrates interactions between components according to the defined sync strategy and error handling procedures.

The tests will follow arrange-act-assert patterns:
1. Setup initial state and mock behaviors
2. Perform repository operations in sequence
3. Verify state transitions and interactions between components

Through these integration tests, we'll validate that the Job feature operates correctly as a cohesive system, not just as individual components. 