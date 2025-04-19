# JobRepository Refactoring Plan - Hard Bob Style

## Problem Statement

The current `JobRepository` is a fucking monolith implementation with way too many responsibilities. It's like having Wags handle investor relations, trader psych, and office maintenance - one entity with too many fucking hats. Here's what's wrong:

- **Bloated Implementation**: Single massive class handling read, write, delete, and sync operations
- **Excessive Comments**: Verbose documentation that bloats the file
- **Poor Type Safety**: Using `Map<String, dynamic>` instead of proper types
- **Unclear ID Contracts**: Doesn't make explicit which ID to use (localId vs serverId)
- **Poor Testability**: Testing the whole repository requires complex mocking hell

## Improved Architecture

We'll split this fucker into a single clean interface and specialized service components with clear, focused responsibilities.

```mermaid
graph TD
    subgraph "Public API"
        JobRepository[JobRepository<br>Interface]
        JobRepositoryImpl[JobRepositoryImpl<br>Class]
        JobRepositoryImpl -->|implements| JobRepository
    end
    
    subgraph "Service Layer"
        ReaderService[JobReaderService]
        WriterService[JobWriterService]
        DeleterService[JobDeleterService]
        SyncService[JobSyncService]
    end
    
    JobRepositoryImpl -->|uses| ReaderService
    JobRepositoryImpl -->|uses| WriterService
    JobRepositoryImpl -->|uses| DeleterService
    JobRepositoryImpl -->|uses| SyncService
    
    subgraph "Data Sources & Infrastructure"
        LocalDS[JobLocalDataSource]
        RemoteDS[JobRemoteDataSource]
        Network[NetworkInfo]
        UUID[UuidGenerator]
        FileSystem[FileSystem]
    end
    
    ReaderService -->|uses| LocalDS
    ReaderService -->|uses| RemoteDS
    
    WriterService -->|uses| LocalDS
    WriterService -->|uses| UUID
    
    DeleterService -->|uses| LocalDS
    DeleterService -->|uses| FileSystem
    
    SyncService -->|uses| LocalDS
    SyncService -->|uses| RemoteDS
    SyncService -->|uses| Network
```

## Key Architecture Principles

1. **Single Public Interface**: 
   - `JobRepository` remains the only public interface with all operations
   - No interface explosion, no unnecessary abstraction

2. **Specialized Service Classes**:
   - Implementation details split into focused service classes
   - Each service handles one aspect (read/write/delete/sync)
   - Services are proper components, not implementation details
   - Direct dependency injection for better testability

3. **Improved Testability**:
   - Each service can be tested in isolation
   - Fewer dependencies to mock per test class
   - Clear separation of concerns in the tests

4. **Clean Dependency Management**:
   - Services get their dependencies directly
   - No complex dependency wiring through the repository

## JobRepository Interface

```dart
/// Manages job data including local persistence, remote sync, and CRUD operations
abstract class JobRepository {
  /// FETCHING OPERATIONS
  
  /// Fetches all jobs for current user
  /// Returns right(jobs) on success or left(failure) on error
  Future<Either<Failure, List<Job>>> getJobs();

  /// Fetches single job by its localId
  /// Returns right(job) if found or left(failure) if not
  Future<Either<Failure, Job>> getJobById(String localId);

  /// WRITE OPERATIONS
  
  /// Creates new job with audio file and optional text
  /// Returns right(job) on success with localId assigned
  Future<Either<Failure, Job>> createJob({
    required String audioFilePath,
    String? text,
  });

  /// Updates existing job by localId with specified changes
  /// Returns right(job) with updated values on success
  Future<Either<Failure, Job>> updateJob({
    required String localId,
    required JobUpdateData updates,
  });
  
  /// DELETE OPERATIONS
  
  /// Marks job for deletion by localId
  /// Returns right(unit) on success
  /// Job is deleted locally after next successful sync
  Future<Either<Failure, Unit>> deleteJob(String localId);
  
  /// SYNC OPERATIONS
  
  /// Syncs all pending jobs with remote server
  /// Processes creates, updates, and deletions
  /// Returns right(unit) when sync process completes
  Future<Either<Failure, Unit>> syncPendingJobs();

  /// Syncs a single job with remote server
  /// Returns right(job) with updated state from server
  Future<Either<Failure, Job>> syncSingleJob(Job job);
}
```

## Implementation Details

### JobRepositoryImpl

```dart
/// Main implementation of JobRepository that delegates to specialized services
class JobRepositoryImpl implements JobRepository {
  final JobReaderService _readerService;
  final JobWriterService _writerService;
  final JobDeleterService _deleterService;
  final JobSyncService _syncService;
  
  JobRepositoryImpl({
    required JobReaderService readerService,
    required JobWriterService writerService,
    required JobDeleterService deleterService,
    required JobSyncService syncService,
  }) : 
    _readerService = readerService,
    _writerService = writerService,
    _deleterService = deleterService,
    _syncService = syncService;
  
  // Read operations
  @override
  Future<Either<Failure, List<Job>>> getJobs() => _readerService.getJobs();
  
  @override
  Future<Either<Failure, Job>> getJobById(String localId) => 
      _readerService.getJobById(localId);
  
  // Write operations
  @override
  Future<Either<Failure, Job>> createJob({
    required String audioFilePath, 
    String? text
  }) => _writerService.createJob(audioFilePath: audioFilePath, text: text);
  
  @override
  Future<Either<Failure, Job>> updateJob({
    required String localId,
    required JobUpdateData updates,
  }) => _writerService.updateJob(localId: localId, updates: updates);
  
  // Delete operations
  @override
  Future<Either<Failure, Unit>> deleteJob(String localId) => 
      _deleterService.deleteJob(localId);
  
  // Sync operations
  @override
  Future<Either<Failure, Unit>> syncPendingJobs() => _syncService.syncPendingJobs();
  
  @override
  Future<Either<Failure, Job>> syncSingleJob(Job job) => _syncService.syncSingleJob(job);
}
```

### JobReaderService

```dart
/// Service class for job read operations
class JobReaderService {
  final JobLocalDataSource _localDataSource;
  final JobRemoteDataSource _remoteDataSource;
  
  JobReaderService(this._localDataSource, this._remoteDataSource);
  
  Future<Either<Failure, List<Job>>> getJobs() async {
    try {
      // Get local jobs
      final localJobs = await _localDataSource.getJobs();
      
      // Logic to determine if fresh enough or if remote fetch needed
      // ...
      
      return Right(localJobs);
    } on Exception catch (e) {
      return Left(CacheFailure());
    }
  }
  
  Future<Either<Failure, Job>> getJobById(String localId) async {
    try {
      final job = await _localDataSource.getJobById(localId);
      return Right(job);
    } on Exception catch (e) {
      return Left(CacheFailure());
    }
  }
  
  Future<Either<Failure, List<Job>>> getJobsByStatus(SyncStatus status) async {
    try {
      final jobs = await _localDataSource.getJobsByStatus(status);
      return Right(jobs);
    } on Exception catch (e) {
      return Left(CacheFailure());
    }
  }
}
```

### JobWriterService

```dart
/// Service class for job write operations
class JobWriterService {
  final JobLocalDataSource _localDataSource;
  final UuidGenerator _uuidGenerator;
  
  JobWriterService(this._localDataSource, this._uuidGenerator);
  
  Future<Either<Failure, Job>> createJob({
    required String audioFilePath,
    String? text,
  }) async {
    try {
      final localId = _uuidGenerator.generate();
      
      final job = Job(
        localId: localId,
        serverId: null,
        text: text,
        audioFilePath: audioFilePath,
        syncStatus: SyncStatus.pending,
        createdAt: DateTime.now(),
      );
      
      await _localDataSource.saveJob(job);
      return Right(job);
    } on Exception catch (e) {
      return Left(CacheFailure());
    }
  }
  
  Future<Either<Failure, Job>> updateJob({
    required String localId,
    required JobUpdateData updates,
  }) async {
    try {
      final jobResult = await _localDataSource.getJobById(localId);
      
      // Apply updates to job
      final updatedJob = jobResult.copyWith(
        text: updates.text ?? jobResult.text,
        status: updates.status ?? jobResult.status,
        syncStatus: SyncStatus.pending, // Mark as needing sync
      );
      
      await _localDataSource.saveJob(updatedJob);
      return Right(updatedJob);
    } on Exception catch (e) {
      return Left(CacheFailure());
    }
  }
  
  Future<Either<Failure, Unit>> updateJobSyncStatus({
    required String localId,
    required SyncStatus status,
  }) async {
    try {
      final jobResult = await _localDataSource.getJobById(localId);
      final updatedJob = jobResult.copyWith(syncStatus: status);
      await _localDataSource.saveJob(updatedJob);
      return Right(unit);
    } on Exception catch (e) {
      return Left(CacheFailure());
    }
  }
}
```

### JobDeleterService

```dart
/// Service class for job deletion operations
class JobDeleterService {
  final JobLocalDataSource _localDataSource;
  final FileSystem _fileSystem;
  
  JobDeleterService(this._localDataSource, this._fileSystem);
  
  Future<Either<Failure, Unit>> deleteJob(String localId) async {
    try {
      final jobResult = await _localDataSource.getJobById(localId);
      
      // Mark for deletion by updating sync status
      final jobToDelete = jobResult.copyWith(
        syncStatus: SyncStatus.pendingDeletion,
      );
      
      await _localDataSource.saveJob(jobToDelete);
      return Right(unit);
    } on Exception catch (e) {
      return Left(CacheFailure());
    }
  }
  
  Future<Either<Failure, Unit>> permanentlyDeleteJob(String localId) async {
    try {
      final jobResult = await _localDataSource.getJobById(localId);
      
      // Delete the job from local storage
      await _localDataSource.deleteJob(localId);
      
      // Delete associated audio file if exists
      if (jobResult.audioFilePath != null) {
        try {
          await _fileSystem.deleteFile(jobResult.audioFilePath!);
        } catch (e) {
          // Log but don't fail the operation if file deletion fails
          // Audio file deletion is a non-critical operation
        }
      }
      
      return Right(unit);
    } on Exception catch (e) {
      return Left(CacheFailure());
    }
  }
}
```

### JobSyncService

```dart
/// Service class for job synchronization with remote server
class JobSyncService {
  final JobLocalDataSource _localDataSource;
  final JobRemoteDataSource _remoteDataSource;
  final NetworkInfo _networkInfo;
  final FileSystem _fileSystem;
  
  JobSyncService({
    required JobLocalDataSource localDataSource,
    required JobRemoteDataSource remoteDataSource,
    required NetworkInfo networkInfo,
    required FileSystem fileSystem,
  }) : 
    _localDataSource = localDataSource,
    _remoteDataSource = remoteDataSource,
    _networkInfo = networkInfo,
    _fileSystem = fileSystem;
  
  Future<Either<Failure, Unit>> syncPendingJobs() async {
    // Check network connectivity
    if (!await _networkInfo.isConnected) {
      return Left(NetworkFailure());
    }
    
    try {
      // Get all pending jobs (new or updated)
      final pendingJobs = await _localDataSource.getJobsByStatus(SyncStatus.pending);
      
      // Get all jobs pending deletion
      final deletionJobs = await _localDataSource.getJobsByStatus(SyncStatus.pendingDeletion);
      
      // Process each pending job
      for (final job in pendingJobs) {
        final syncResult = await syncSingleJob(job);
        // Error handling done in syncSingleJob
      }
      
      // Process each job pending deletion
      for (final job in deletionJobs) {
        if (job.serverId != null) {
          // Delete on server if it exists there
          try {
            await _remoteDataSource.deleteJob(job.serverId!);
          } catch (e) {
            // Log error but continue with other operations
          }
        }
        
        // Always delete locally regardless of server success
        await _permanentlyDeleteJob(job.localId);
      }
      
      return Right(unit);
    } on Exception catch (e) {
      return Left(ServerFailure());
    }
  }
  
  Future<Either<Failure, Job>> syncSingleJob(Job job) async {
    try {
      if (job.serverId == null) {
        // This is a new job, create on server
        final remoteJob = await _remoteDataSource.createJob(job);
        
        // Update local job with server details
        final updatedJob = job.copyWith(
          serverId: remoteJob.serverId,
          syncStatus: SyncStatus.synced,
        );
        
        // Save updated job locally
        await _localDataSource.saveJob(updatedJob);
        
        return Right(updatedJob);
      } else {
        // This is an existing job, update on server
        final remoteJob = await _remoteDataSource.updateJob(job);
        
        // Update local job with sync status
        final updatedJob = job.copyWith(
          syncStatus: SyncStatus.synced,
        );
        
        await _localDataSource.saveJob(updatedJob);
        
        return Right(updatedJob);
      }
    } catch (e) {
      // If sync fails, mark job with error status
      final errorJob = job.copyWith(syncStatus: SyncStatus.error);
      await _localDataSource.saveJob(errorJob);
      
      return Left(ServerFailure());
    }
  }
  
  // Internal helper method to delete job permanently
  Future<void> _permanentlyDeleteJob(String localId) async {
    try {
      final job = await _localDataSource.getJobById(localId);
      
      // Delete the job from local storage
      await _localDataSource.deleteJob(localId);
      
      // Delete associated audio file if exists
      if (job.audioFilePath != null) {
        try {
          await _fileSystem.deleteFile(job.audioFilePath!);
        } catch (e) {
          // Log but don't fail the operation if file deletion fails
        }
      }
    } catch (e) {
      // Log but continue with sync operations
    }
  }
}
```

## JobUpdateData Class

```dart
/// Model class for job updates with explicit fields
class JobUpdateData {
  final String? text;
  final JobStatus? status;
  final String? serverId; // Added for sync operations
  // Add other fields that can be updated
  
  const JobUpdateData({
    this.text,
    this.status,
    this.serverId,
  });
  
  // Optional utility to check if instance has any non-null fields
  bool get hasChanges => text != null || status != null || serverId != null;
}
```

## File Organization

```
lib/
  features/
    jobs/
      data/
        repositories/
          job_repository.dart             # Interface definition
          job_repository_impl.dart        # Main implementation
        services/
          job_reader_service.dart         # Reader implementation
          job_writer_service.dart         # Writer implementation
          job_deleter_service.dart        # Deleter implementation
          job_sync_service.dart           # Sync implementation
        models/
          job_update_data.dart            # Update model
```

## Dependency Injection Setup

```dart
// Register data sources
sl.registerLazySingleton<JobLocalDataSource>(() => HiveJobLocalDataSourceImpl(
  sl<HiveInterface>(),
));

sl.registerLazySingleton<JobRemoteDataSource>(() => ApiJobRemoteDataSourceImpl(
  sl<HttpClient>(),
));

// Register services
sl.registerLazySingleton(() => JobReaderService(
  sl<JobLocalDataSource>(),
  sl<JobRemoteDataSource>(),
));

sl.registerLazySingleton(() => JobWriterService(
  sl<JobLocalDataSource>(),
  sl<UuidGenerator>(),
));

sl.registerLazySingleton(() => JobDeleterService(
  sl<JobLocalDataSource>(),
  sl<FileSystem>(),
));

sl.registerLazySingleton(() => JobSyncService(
  localDataSource: sl<JobLocalDataSource>(),
  remoteDataSource: sl<JobRemoteDataSource>(),
  networkInfo: sl<NetworkInfo>(),
  fileSystem: sl<FileSystem>(),
));

// Register repository
sl.registerLazySingleton<JobRepository>(() => JobRepositoryImpl(
  readerService: sl<JobReaderService>(),
  writerService: sl<JobWriterService>(),
  deleterService: sl<JobDeleterService>(),
  syncService: sl<JobSyncService>(),
));
```

## Migration Strategy

1. **Create Service Classes**: Define all service classes in their own files
2. **Create Data Models**: Define `JobUpdateData` and other models
3. **Update JobRepository Interface**: Clean up the interface with logical grouping
4. **Implement JobRepositoryImpl**: Simple implementation delegating to services
5. **Update DI Container**: Register services and repository with dependencies
6. **Update Usage Sites**: Replace Map<String, dynamic> with JobUpdateData, etc.
7. **Comprehensive Testing**: Test each service in isolation with focused unit tests

## TODO List - Hard Bob Style

-   [x] **1. Setup:**
    -   [x] Create file structure under `lib/features/jobs/data/services/`
    -   [x] Create `JobUpdateData` model (`lib/features/jobs/data/models/job_update_data.dart`)
-   [x] **2. JobReaderService:**
    -   [x] Create `job_reader_service.dart`
    -   [x] Create `job_reader_service_test.dart`
    -   [x] Write tests for `getJobs` (steal from `get_jobs_test.dart`)
    -   [x] Implement `getJobs`
    -   [x] Write tests for `getJobById` (steal from `get_jobs_test.dart`)
    -   [x] Implement `getJobById`
    -   [x] Write tests for `getJobsByStatus` (new functionality)
    -   [x] Implement `getJobsByStatus`
-   [x] **3. JobWriterService:**
    -   [x] Create `job_writer_service.dart`
    -   [x] Create `job_writer_service_test.dart`
    -   [x] Write tests for `createJob` (steal from `create_job_test.dart`)
    -   [x] Implement `createJob`
    -   [x] Write tests for `updateJob` (steal from `update_job_test.dart`)
    -   [x] Implement `updateJob`
    -   [x] Write tests for `updateJobSyncStatus` (new functionality)
    -   [x] Implement `updateJobSyncStatus`
-   [x] **4. JobDeleterService:**
    -   [x] Create `job_deleter_service.dart`
    -   [x] Create `job_deleter_service_test.dart`
    -   [x] Write tests for `deleteJob` (steal from `delete_job_test.dart`)
    -   [x] Implement `deleteJob`
    -   [x] Write tests for `permanentlyDeleteJob` (new functionality)
    -   [x] Implement `permanentlyDeleteJob`
-   [x] **5. JobSyncService:**
    -   [x] Create `job_sync_service.dart`
    -   [x] Create `job_sync_service_test.dart`
    -   [x] Write tests for `syncPendingJobs` (steal from `sync_pending_jobs_test.dart`) --> *Partially done - one test written* --> **UPDATE: Added deletion test**
    -   [x] Implement `syncPendingJobs` and `_permanentlyDeleteJob` helper
    -   [x] Write tests for `syncSingleJob` (steal from `sync_pending_jobs_test.dart`) --> *Success and Error cases done*
    -   [x] Implement `syncSingleJob`

-   [x] **6. JobRepository:**
    -   [x] Clean up `JobRepository` interface (`lib/features/jobs/domain/repositories/job_repository.dart`)
    -   [x] Implement `JobRepositoryImpl` (`lib/features/jobs/data/repositories/job_repository_impl.dart`)
    -   [x] Write/Update tests for `JobRepositoryImpl` (verify delegation)

-   [x] **7. Integration & Cleanup:**
    -   [x] Update DI Container (`lib/core/di/injection_container.dart` or similar)
    -   [x] Move old `JobLocalDataSource` and `JobRemoteDataSource` tests/mocks to `_backup_old_tests` folder
    -   [x] Move old `JobRepositoryImpl` tests to `_backup_old_tests` folder
    -   [x] Final `dart analyze` (ignoring DI errors) and `flutter test` run (all pass)
    -   [x] Code cleanup (remove unused imports, dead code, etc.)
    -   [x] Hard Bob Commit

-   [x] **8. DI Implementation & Core Services:** (Implement missing core services and register all dependencies)
    -   [x] **Register** `Dio` instance (for `ApiJobRemoteDataSourceImpl`)
    -   [x] **Register** `FileSystemImpl` (`IoFileSystem` exists in `lib/core/platform/file_system.dart`)
    -   [x] Implement/Register `NetworkInfoImpl` - *Verify if standard implementation exists* --> **Implemented `NetworkInfoImpl` and verified it needs `Connectivity` registration.**
    -   [x] **Register** `JobLocalDataSourceImpl` (`HiveJobLocalDataSourceImpl` exists)
    -   [x] **Register** `JobRemoteDataSourceImpl` (`ApiJobRemoteDataSourceImpl` exists)
    -   [x] Verify `dart analyze` is clean (no errors after registration) --> **Done, ignoring one spurious unused import warning.**

-   [x] **9. Job Data Flow Improvements:** (From job_dataflow.md)
    -   [x] Add `JobUpdateData` validation (avoid empty updates)
    -   [x] Add Concurrent Sync Protection (mutex/lock for `syncPendingJobs`)

-   [x] **10. Error Recovery Implementation:**
    -   [x] **10.1 Update Job Entity and Models:** (Foundation)
        -   [x] Add `retryCount` field (int, defaults to 0) to `Job` entity class
        -   [x] Add `lastSyncAttemptAt` field (DateTime?, nullable) to `Job` entity class 
        -   [x] Add `SyncStatus.failed` to the `SyncStatus` enum
        -   [x] Update `Job.copyWith()` to support new fields
        -   [x] Update `JobHiveModel` with corresponding fields
        -   [x] Update `JobMapper` to handle the new fields in both directions

    -   [x] **10.2 Create Sync Configuration:** (Constants used by multiple components)
        -   [x] Create `lib/features/jobs/data/config/job_sync_config.dart` with constants:
          ```dart
          const int MAX_RETRY_ATTEMPTS = 5;
          const Duration RETRY_BACKOFF_BASE = Duration(minutes: 1);
          const Duration SYNC_INTERVAL = Duration(seconds: 15);
          ```

    -   [x] **10.3 Update JobLocalDataSource Interface:** (API contract)
        -   [x] Add `Future<List<Job>> getJobsToRetry(int maxRetries, Duration baseBackoffDuration)` to interface
        -   [x] Write tests for the new method

    -   [x] **10.4 Update HiveJobLocalDataSourceImpl:** (Implementation)
        -   [x] Implement `getJobsToRetry` with:
          ```dart
          // Return jobs matching these criteria:
          syncStatus == SyncStatus.error &&
          retryCount < maxRetries &&
          (lastSyncAttemptAt == null || 
           lastSyncAttemptAt.isBefore(DateTime.now().subtract(baseBackoffDuration * pow(2, retryCount))))
          ```

    -   [x] **10.5 Update JobSyncService:** (Core sync logic)
        -   [x] Import `dart:math` for `pow` function
        -   [x] Modify `syncPendingJobs()` to fetch and process retry-eligible jobs
        -   [x] Update error handling in `syncSingleJob()` to track retry attempts
        -   [x] Add unit tests for retry functionality
        -   [ ] Create `_handleSyncError(Job job, Exception e)` helper method to reduce duplicated error handling code
        -   [ ] Add strategic comments explaining retry logic and backoff strategy
        -   [ ] Create integration test in `job_sync_integration_test.dart` that simulates complete job lifecycle with retries

    -   [ ] **10.6 Add Reset Failed Jobs Feature:** (Recovery option)
        -   [ ] Add `resetFailedJob(String localId)` method to `JobSyncService`
        -   [ ] Write tests for the new method

    -   [ ] **10.7 Update JobRepository Interface:** (Public API)
        -   [ ] Add `resetFailedJob(String localId)` method to interface
        -   [ ] Update `JobRepositoryImpl` to delegate to `JobSyncService.resetFailedJob`

    -   [ ] **10.8 Implement Background Sync Trigger:**
        -   [ ] Create `JobSyncTriggerService` in `lib/features/jobs/data/services/job_sync_trigger_service.dart`
        -   [ ] Add methods: `startPeriodicSync()`, `stopPeriodicSync()`, and `_triggerSync(Timer)`
        -   [ ] Add tests for `JobSyncTriggerService`

    -   [ ] **10.9 Update Dependency Injection:**
        -   [ ] Register `JobSyncTriggerService` in DI container
        -   [ ] Update app initialization to start sync after DI setup

    -   [ ] **10.10 Add App Lifecycle Management:**
        -   [ ] Create `JobSyncLifecycleObserver` that:
          - Starts sync when app comes to foreground
          - Stops sync when app goes to background
        -   [ ] Register observer with `WidgetsBinding.instance.addObserver`

    -   [ ] **10.11 Update UI for Failed Jobs:** (once UI is in place)
        -   [ ] Add visual indicator for jobs with `SyncStatus.failed` 
        -   [ ] Add "Retry" action for failed jobs that calls `jobRepository.resetFailedJob()`

## Testing Approach

### Unit Testing Service Classes

```