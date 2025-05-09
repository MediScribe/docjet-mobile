# Job Data Layer Flow

This document details the data flow architecture for the Job feature in DocJet Mobile.

> **TLDR:** This is an offline-first architecture with server-side synchronization. Jobs have a dual-ID system (client-generated UUID and server-assigned ID), undergo local-first CRUD operations, are synchronized on a 15-second interval, and can handle network failures with appropriate status tracking. Historical development details can be found in [job_dataflow_development_history.md](./job_dataflow_development_history.md).

## Table of Contents

- [Key Architecture Decisions](#key-architecture-decisions)
- [Directory Structure](#directory-structure)
- [Job Feature Architecture Overview](#job-feature-architecture-overview)
- [Job Presentation Layer Architecture](./feature-job-presentation.md) - *(See separate document)*
- [Job Data Layer Flow](#job-data-layer-flow)
- [Job Creation, Update, and Sync Flow](#job-creation-update-and-sync-flow)
- [Job Data Layer Components](#job-data-layer-components)
  - [Service-Oriented Repository Pattern](#service-oriented-repository-pattern)
    - [JobRepository Interface](#jobrepository-interface)
    - [JobRepositoryImpl](#jobrepositoryimpl)
    - [JobReaderService](#jobreaderservice)
    - [JobWriterService](#jobwriterservice)
    - [JobDeleterService](#jobdeleterservice)
    - [JobSyncOrchestratorService](#jobsyncorchestratorservice)
    - [JobSyncProcessorService](#jobsyncprocessorservice)
    - [JobSyncTriggerService](#jobsynctriggerservice)
  - [Data Sources](#data-sources)
    - [JobLocalDataSource](#joblocaldatasource)
    - [JobRemoteDataSource](#jobremotedatasource)
  - [Job Model Enhancements](#job-model-enhancements)
    - [SyncStatus Enum](#syncstatus-enum)
    - [Job Entity](#job-entity)
- [Sync Strategy](#sync-strategy)
  - [Core Principles](#core-principles)
  - [Sync Architecture](#sync-architecture)
  - [Sync Process Details](#sync-process-details)
  - [Server-Side Deletion Handling](#server-side-deletion-handling)
  - [Audio File Management](#audio-file-management)
  - [Authentication Integration](#authentication-integration)
- [Background Processing Support](#background-processing-support)
- [Remaining Improvements](#remaining-improvements)
- [Synchronization Flow Diagrams](#synchronization-flow-diagrams)
  - [Sync Orchestration - Job Collection](#sync-orchestration---job-collection)
  - [Sync Orchestration - Delegation](#sync-orchestration---delegation)
  - [Processor - New Job Creation](#processor---new-job-creation)
  - [Processor - Job Update](#processor---job-update)
  - [Processor - Sync Error Handling](#processor---sync-error-handling)
  - [Processor - Job Deletion](#processor---job-deletion)
  - [Processor - Local File Cleanup](#processor---local-file-cleanup)
  - [Manual Reset of Failed Job](#manual-reset-of-failed-job)
- [Local-First Operations Flow](#local-first-operations-flow)
  - [Job Creation Flow](#job-creation-flow)
  - [Job Update Flow](#job-update-flow)
  - [Job Deletion Flow](#job-deletion-flow)

## Key Architecture Decisions

1. **Dual-ID System**
   * `localId`: Client-generated UUID that never changes
   * `serverId`: Server-assigned ID after first successful sync
   * Preserves local references while supporting server-generated IDs

2. **Offline-First Operations**
   * All operations (create/update/delete) happen locally first
   * Changes are marked with appropriate sync status
   * Background synchronization pushes changes to server

3. **Individual Job Synchronization**
   * Each job is processed independently with clear paths for:
     - Creating new jobs (`serverId == null`)
     - Updating existing jobs (`serverId != null`)
     - Deleting jobs (`syncStatus == pendingDeletion`)
   * Allows for granular error handling per job

4. **Server Authority Model**
   * Server is the ultimate source of truth
   * Server data overwrites local data after initial sync
   * No conflict resolution - server response is accepted as-is

5. **Robust Error Handling**
   * Per-job error state tracking
   * Failed jobs are retried with exponential backoff
   * Maximum retry attempts with permanent failure state
   * Sync process continues with other jobs even if one fails
   * Non-fatal audio file deletion errors

6. **Resource Management**
   * Audio files tied directly to job lifecycle
   * Automatic cleanup when jobs are deleted (locally or server-side)

7. **Service-Oriented Architecture**
   * Specialized services with single responsibilities
   * Clear separation between read, write, delete, and sync operations
   * Split sync responsibility between Orchestrator (what to sync) and Processor (how to sync)
   * Improved testability with focused components

8. **Background Processing Support**
   * Explicit sync triggering mechanism
   * App lifecycle aware (foreground/background transitions)
   * Compatible with platform-specific background workers

## Directory Structure

### Feature Location
The Job feature is located at: `lib/features/jobs/` (plural)

### Key Components
- **Repository Interface**: `lib/features/jobs/domain/repositories/job_repository.dart`
- **Repository Implementation**: `lib/features/jobs/data/repositories/job_repository_impl.dart`
- **Domain Entities**: `lib/features/jobs/domain/entities/`
  - `job.dart`
  - `job_update_details.dart`
  - `sync_status.dart`

### Service Layer 
All services located in: `lib/features/jobs/data/services/`
- `job_sync_trigger_service.dart` - Periodic sync triggering
- `job_sync_orchestrator_service.dart` - Orchestrates what to sync
- `job_sync_processor_service.dart` - Handles API operations
- `job_reader_service.dart` - Read operations
- `job_writer_service.dart` - Write operations 
- `job_deleter_service.dart` - Delete operations

### Use Cases Layer
All use cases located in: `lib/features/jobs/domain/usecases/`
- `create_job_use_case.dart` - Creates new jobs
- `delete_job_use_case.dart` - Marks jobs for deletion
- `get_job_by_id_use_case.dart` - Retrieves a single job
- `get_jobs_use_case.dart` - Retrieves all jobs
- `reset_failed_job_use_case.dart` - Resets failed jobs for retry
- `update_job_use_case.dart` - Updates existing jobs
- `watch_jobs_use_case.dart` - Provides a stream of all jobs
- `watch_job_by_id_use_case.dart` - Provides a stream for a single job

### Data Sources
- **Local**: `lib/features/jobs/data/datasources/job_local_data_source.dart`
- **Remote**: `lib/features/jobs/data/datasources/job_remote_data_source.dart`
- **Implementations**:
  - `lib/features/jobs/data/datasources/hive_job_local_data_source_impl.dart`
  - `lib/features/jobs/data/datasources/api_job_remote_data_source_impl.dart`

### Models and Mappers
- **Models**: `lib/features/jobs/data/models/`
  - `job_hive_model.dart`
  - `job_api_dto.dart`
- **Mappers**: `lib/features/jobs/data/mappers/job_mapper.dart`

### Tests
Test files are located at: `test/features/jobs/data/services/`
- Each service has corresponding test files
- Mock files are generated with `@GenerateMocks` annotations

## Job Feature Architecture Overview

The following diagrams illustrate the components and their relationships for the job feature.

> **Note:** For details on the Presentation Layer (Cubits, States, UI interaction), see the dedicated [Job Presentation Layer Architecture](./feature-job-presentation.md) document.

### High-Level Architecture

This diagram shows the main architectural layers and primary flow of data:

```mermaid
%%{init: {'flowchart': {'defaultRenderer': 'elk'}}}%%
graph TD
    subgraph "Presentation Layer"
        UI[Job List UI] 
        StateManagement[Job State Management]
        UI <--> StateManagement
    end

    subgraph "Use Cases Layer"
        GetJobs[GetJobsUseCase]
        GetJobById[GetJobByIdUseCase]
        CreateJob[CreateJobUseCase]
        UpdateJob[UpdateJobUseCase]
        DeleteJob[DeleteJobUseCase]
        ResetFailedJob[ResetFailedJobUseCase]
    end

    subgraph "Domain Layer"
        JobRepo[JobRepository Interface]
        JobEntity[Job Entity]
        SyncStatus[Sync Status Enum]
    end

    subgraph "Data Layer"
        RepoImpl[JobRepositoryImpl]
        Services[Specialized Services]
        DataSources[Data Sources]
    end

    %% Connections between layers
    StateManagement --> GetJobs
    StateManagement --> GetJobById
    StateManagement --> CreateJob
    StateManagement --> UpdateJob
    StateManagement --> DeleteJob
    StateManagement --> ResetFailedJob
    
    GetJobs --> JobRepo
    GetJobById --> JobRepo
    CreateJob --> JobRepo
    UpdateJob --> JobRepo
    DeleteJob --> JobRepo
    ResetFailedJob --> JobRepo
    
    JobRepo -- Defines --> JobEntity
    JobEntity -- Uses --> SyncStatus
    
    RepoImpl --> JobRepo
    RepoImpl --> Services
    Services --> DataSources

    %% Styling
    class UI,StateManagement presentation;
    class GetJobs,GetJobById,CreateJob,UpdateJob,DeleteJob,ResetFailedJob usecases;
    class JobRepo,JobEntity,SyncStatus domain;
    class RepoImpl,Services,DataSources data;
```

### Data Layer Services Detail

This diagram shows the details of the Service-Oriented Repository Pattern implementation:

```mermaid
%%{init: {'flowchart': {'defaultRenderer': 'elk'}}}%%
graph TD
    %% Repository Implementation
    RepoImpl[JobRepositoryImpl]
    
    %% Services
    subgraph "Services Layer"
        ReaderSvc[JobReaderService]
        WriterSvc[JobWriterService]
        DeleterSvc[JobDeleterService]
        SyncOrch[JobSyncOrchestratorService]
        SyncProc[JobSyncProcessorService]
        SyncTrigger[JobSyncTriggerService]
    end
    
    %% Data Sources
            LocalDS[JobLocalDataSource]
            RemoteDS[JobRemoteDataSource]
    
    %% Infrastructure
            Network[NetworkInfo]
            UUID[UuidGenerator]
            FileSystem[FileSystem]
    
    %% Connections
    RepoImpl --> ReaderSvc
    RepoImpl --> WriterSvc
    RepoImpl --> DeleterSvc
    RepoImpl --> SyncOrch
    
    SyncTrigger -->|Calls| SyncOrch
    SyncOrch -->|Delegates to| SyncProc
    
    ReaderSvc --> LocalDS
    ReaderSvc --> RemoteDS
        
    WriterSvc --> LocalDS
    WriterSvc --> UUID
        
    DeleterSvc --> LocalDS
    DeleterSvc --> FileSystem
        
    SyncOrch --> LocalDS
    SyncOrch --> Network
        
    SyncProc --> LocalDS
    SyncProc --> RemoteDS
    SyncProc --> FileSystem
    
    %% Implementation Details
    LocalDSImpl[HiveJobLocalDataSourceImpl]
    RemoteDSImpl[ApiJobRemoteDataSourceImpl]
    
    LocalDSImpl -->|Implements| LocalDS
    RemoteDSImpl -->|Implements| RemoteDS
    
    %% Styling
    class ReaderSvc,WriterSvc,DeleterSvc,SyncOrch,SyncProc,SyncTrigger service;
    class RepoImpl,LocalDS,RemoteDS,LocalDSImpl,RemoteDSImpl data;
    class Network,UUID,FileSystem infra;
```

## Job Data Layer Flow

This sequence diagram shows the typical flows when the application requests job data, demonstrating how the repository interacts with local and remote data sources.

```mermaid
sequenceDiagram
    autonumber
    participant UseCase as Use Case
    participant JobRepo as JobRepositoryImpl
    participant ReaderSvc as JobReaderService
    participant LocalDS as HiveJobLocalDS
    participant RemoteDS as ApiJobRemoteDS
    participant Mapper as JobMapper
    participant ApiDTO as JobApiDTO
    participant Hive as Hive Box
    participant API as REST API

    Note over UseCase, API: Fetching Job List

    %% Success Path - Local Data
    Note over UseCase, API: Success Path - Local Cache Hit
    UseCase->>JobRepo: getJobs()
    JobRepo->>ReaderSvc: getJobs()
    ReaderSvc->>LocalDS: getJobs()
    LocalDS->>Hive: readAllJobs()
    Hive-->>LocalDS: List<JobHiveModel> (fresh data)
    LocalDS->>Mapper: fromHiveModelList(hiveModels)
    Mapper-->>LocalDS: List<JobEntity>
    LocalDS-->>ReaderSvc: List<JobEntity>
    ReaderSvc-->>JobRepo: Right<List<JobEntity>>
    JobRepo-->>UseCase: Right<List<JobEntity>>
    
    %% Refresh Path - Remote Fetch
    Note over UseCase, API: Refresh Path - Local Cache Miss/Stale
    UseCase->>JobRepo: getJobs()
    JobRepo->>ReaderSvc: getJobs()
    ReaderSvc->>LocalDS: getJobs()
    LocalDS->>Hive: readAllJobs()
    Hive-->>LocalDS: Empty or stale data
    LocalDS-->>ReaderSvc: Empty List or Stale Indicator
    ReaderSvc->>RemoteDS: fetchJobs()
    RemoteDS->>API: GET /api/v1/jobs
    API-->>RemoteDS: Job JSON Array
    RemoteDS->>ApiDTO: fromJson(jsonData)
    ApiDTO-->>RemoteDS: List<JobApiDTO>
    RemoteDS->>Mapper: fromApiDtoList(jobApiDtos)
    Mapper-->>RemoteDS: List<JobEntity>
    RemoteDS-->>ReaderSvc: List<JobEntity>
    ReaderSvc->>LocalDS: saveJobs(fetchedJobs)
    LocalDS->>Mapper: toHiveModelList(jobEntities)
    Mapper-->>LocalDS: List<JobHiveModel>
    LocalDS->>Hive: writeAllJobs(hiveModels)
    Hive-->>LocalDS: Save Confirmation
    LocalDS-->>ReaderSvc: Save Confirmation
    ReaderSvc-->>JobRepo: Right<List<JobEntity>>
    JobRepo-->>UseCase: Right<List<JobEntity>>
    
    %% Error Path
    Note over UseCase, API: Error Path - Network/Server Failure
    UseCase->>JobRepo: getJobs()
    JobRepo->>ReaderSvc: getJobs()
    ReaderSvc->>LocalDS: getJobs()
    LocalDS->>Hive: readAllJobs()
    Hive-->>LocalDS: Empty or stale data
    LocalDS-->>ReaderSvc: Empty List or Stale Indicator
    ReaderSvc->>RemoteDS: fetchJobs()
    RemoteDS->>API: GET /api/v1/jobs
    API-->>RemoteDS: Error Response (5xx, network error)
    RemoteDS-->>ReaderSvc: Exception/Error
    ReaderSvc-->>JobRepo: Left<Failure>
    JobRepo-->>UseCase: Left<Failure>
```

## Job Creation, Update, and Sync Flow

This sequence diagram illustrates the data flow for creating new jobs, updating existing jobs, and synchronizing pending changes with the backend.

```mermaid
sequenceDiagram
    autonumber
    participant UseCase as Use Case
    participant JobRepo as JobRepositoryImpl
    participant WriterSvc as JobWriterService
    participant DeleterSvc as JobDeleterService
    participant SyncOrch as JobSyncOrchestratorService
    participant SyncProc as JobSyncProcessorService
    participant LocalDS as HiveJobLocalDS
    participant RemoteDS as ApiJobRemoteDS
    participant Mapper as JobMapper
    participant UUID as UUID Generator
    participant Hive as Hive Box
    participant API as REST API
    participant FileSystem as File System

    %% Job Creation Flow
    Note over UseCase, API: Job Creation - Local First
    UseCase->>JobRepo: createJob(audioFilePath, text)
    JobRepo->>WriterSvc: createJob(audioFilePath, text)
    WriterSvc->>UUID: Generate UUID for new job
    UUID-->>WriterSvc: new localId
    WriterSvc->>WriterSvc: Create Job entity with:<br/>- localId<br/>- serverId=null<br/>- SyncStatus.pending
    WriterSvc->>LocalDS: saveJob(job)
    LocalDS->>Mapper: toHiveModel(jobEntity)
    Mapper-->>LocalDS: JobHiveModel
    LocalDS->>Hive: Save to Hive Box (keyed by localId)
    Hive-->>LocalDS: Save Confirmation
    LocalDS-->>WriterSvc: Success
    WriterSvc-->>JobRepo: Right<Job>
    
    Note over JobRepo, SyncOrch: Immediate Sync Triggered (Fire-and-forget)
    JobRepo->>SyncOrch: syncPendingJobs()
    JobRepo-->>UseCase: Right<Job>
    
    Note over SyncOrch, API: Asynchronous Sync Process (non-blocking)
    SyncOrch->>SyncProc: processJobSync(job)
    SyncProc->>RemoteDS: createJob(job)
    RemoteDS->>API: POST /api/v1/jobs
    API-->>RemoteDS: Job JSON with serverId
    
    %% Job Update Flow
    Note over UseCase, API: Job Update - Local First
    UseCase->>JobRepo: updateJob(localId, updates)
    JobRepo->>WriterSvc: updateJob(localId, updates)
    WriterSvc->>LocalDS: getJobById(localId)
    LocalDS->>Hive: Read from Hive Box
    Hive-->>LocalDS: JobHiveModel
    LocalDS->>Mapper: fromHiveModel(model)
    Mapper-->>LocalDS: Job
    LocalDS-->>WriterSvc: Job
    
    WriterSvc->>WriterSvc: Validate updates.hasChanges
    
    alt Updates contain changes
        WriterSvc->>WriterSvc: Apply updates and set SyncStatus.pending
        WriterSvc->>LocalDS: saveJob(updatedJob)
        LocalDS->>Mapper: toHiveModel(job)
        Mapper-->>LocalDS: JobHiveModel
        LocalDS->>Hive: Save to Hive Box
        Hive-->>LocalDS: Save Confirmation
        LocalDS-->>WriterSvc: Success
        WriterSvc-->>JobRepo: Right<Job>
    else No changes detected
        WriterSvc-->>JobRepo: Right<Job> (unchanged)
    end
    
    JobRepo-->>UseCase: Right<Job>
    
    %% Job Deletion Flow
    Note over UseCase, API: Job Deletion - Local First
    UseCase->>JobRepo: deleteJob(localId)
    JobRepo->>DeleterSvc: deleteJob(localId)
    DeleterSvc->>LocalDS: getJobById(localId)
    LocalDS->>Hive: Read from Hive Box
    Hive-->>LocalDS: JobHiveModel
    LocalDS->>Mapper: fromHiveModel(model)
    Mapper-->>LocalDS: Job
    LocalDS-->>DeleterSvc: Job
    
    DeleterSvc->>DeleterSvc: Set SyncStatus.pendingDeletion
    DeleterSvc->>LocalDS: saveJob(updatedJob)
    LocalDS->>Mapper: toHiveModel(job)
    Mapper-->>LocalDS: JobHiveModel
    LocalDS->>Hive: Save to Hive Box
    Hive-->>LocalDS: Save Confirmation
    LocalDS-->>DeleterSvc: Success
    DeleterSvc-->>JobRepo: Right<Unit>
    JobRepo-->>UseCase: Right<Unit>
```

## Job Data Layer Components

### Service-Oriented Repository Pattern

The job feature implements a service-oriented repository pattern with specialized services for different operations.

#### JobRepository Interface

The public contract for job operations that feature modules interact with. It defines all operations without exposing implementation details.

Key Methods:
* Read: `getJobs()`, `getJobById(localId)` (returns `Job?`)
* Write: `createJob(audioFilePath, text)`, `updateJob(localId, updates)`
* Delete: `deleteJob(localId)`
* Sync: `syncPendingJobs()`, `resetFailedJob(localId)`
* Reactive Read: `watchJobs()`, `watchJobById(localId)` (return Streams)

#### JobRepositoryImpl

Lightweight implementation that delegates to specialized services:

```dart
class JobRepositoryImpl implements JobRepository {
  final JobReaderService _readerService;
  final JobWriterService _writerService;
  final JobDeleterService _deleterService;
  final JobSyncOrchestratorService _orchestratorService;
  
  // Methods delegate directly to appropriate service
  Future<Either<Failure, List<Job>>> getJobs() => _readerService.getJobs();
  
  // Job creation with immediate sync
  Future<Either<Failure, Job>> createJob({required String audioFilePath, String? text}) async {
    final Either<Failure, Job> result = await _writerService.createJob(audioFilePath: audioFilePath, text: text);
    
    // After successful local creation, trigger immediate sync (fire-and-forget)
    result.fold(
      (failure) => null, // Do nothing on failure
      (job) => _triggerImmediateSync(job) // Trigger sync on success
    );
    
    return result; // Return original result regardless of sync outcome
  }
  
  // Other methods follow the same pattern...
}
```

Key features:
* Delegates to specialized services for different operations
* Authenticates user before job creation operations
* Triggers immediate sync after successful local job creation (fire-and-forget)
* Propagates results from services directly to callers
* Properly manages auth event subscriptions

#### JobReaderService

Handles all read operations related to jobs.

Key features:
* Getting jobs from local storage
* Fetching jobs from remote API when needed
* Detecting server-side deletions
* Providing reactive streams via `watchJobs()` and `watchJobById()`
* Managing server-to-local ID mapping for API/local sync
  * Builds a `serverIdToLocalIdMap` to preserve local IDs across sync operations
  * Ensures domain entities consistently use the same localId for a given server record
  * Fixes critical bug where jobs were incorrectly assigned empty localIds

#### JobWriterService

Handles all job creation and update operations.

Key features:
* Creating new jobs with client-generated UUID
* Validating updates to avoid unnecessary processing
* Marking jobs for sync

#### JobDeleterService

Handles all job deletion operations.

Key features:
* Marking jobs for deletion (soft delete)
* Permanently deleting jobs after sync
* Cleaning up associated audio files

#### JobSyncOrchestratorService

Orchestrates the synchronization process by determining what needs to be synced and delegating the actual sync operations.

Key features:
* Collecting jobs that need synchronization (pending, pendingDeletion, retry-eligible)
* Network connectivity verification
* Concurrency protection with mutex
* Delegating individual job processing to the processor service
* Resetting failed jobs upon user request

#### JobSyncProcessorService

Handles the actual synchronization operations with the remote API.

Key features:
* Processing different sync paths (create/update/delete) 
* Making API calls to create, update, or delete jobs
* Error handling with retry mechanism
* Updating job status based on sync results
* Managing audio file cleanup after successful deletion

#### JobSyncTriggerService

Manages periodic sync operation triggered by timer or app lifecycle events.

Key features:
* 15-second periodic timer for sync
* App lifecycle awareness (background/foreground)
* Error handling for sync operation

### Data Sources

#### JobLocalDataSource

Interface defining operations for local storage of jobs. Implemented by `HiveJobLocalDataSourceImpl`.

Key methods include:
* `getJobsToRetry(maxRetries, backoffDuration)`: Gets jobs eligible for retry based on retry count and backoff time
* `watchJobs()`: Returns a `Stream` of the entire job list.
* `watchJobById(id)`: Returns a `Stream` for a specific job.

#### JobRemoteDataSource

Interface for remote API operations. Implemented by `ApiJobRemoteDataSourceImpl`.

Key features:
* Handles direct communication with the REST API
* Returns `JobApiDTO` objects instead of domain entities
* Uses `AuthSessionProvider` to get the current user ID for job operations rather than requiring it as a parameter
* Provides proper authentication error handling
* Wraps API failures in domain-specific exceptions

##### ApiJobRemoteDataSourceImpl
- **Implementation**: `lib/features/jobs/data/datasources/api_job_remote_data_source_impl.dart`
- **Purpose**: Implements `JobRemoteDataSource` using `Dio` for HTTP requests.
- **Key Responsibilities**:
  - Fetching all jobs as DTOs (`GET /jobs`) - returns `List<JobApiDTO>` that the service layer maps to domain entities
  - Fetching a single job by ID (`GET /jobs/{id}`).
  - Creating a new job (`POST /jobs` with multipart/form-data for audio).
  - Updating an existing job (`PATCH /jobs/{id}`).
  - Deleting a job (`DELETE /jobs/{id}`).
- **Data Transfer**: 
  - For `fetchJobs()`, the implementation returns raw `JobApiDTO` objects and leaves ID mapping to the service layer
  - This maintains separation of concerns where data sources handle API communication and services handle domain mapping
- **Authentication**: 
  - This implementation receives the `authenticatedDio` instance (configured with base URL and authentication interceptors) via dependency injection.
  - All API calls (`GET`, `POST`, `PATCH`, `DELETE`) to the `/jobs/...` endpoints require authentication and utilize this injected `authenticatedDio` instance.
  - This aligns with the Split Client pattern detailed in [feature-auth-architecture.md](../../core/feature-auth-architecture.md).
- **Error Handling**: Maps HTTP errors and `Dio` exceptions to domain-specific exceptions (e.g., `ApiException`).
- **Dependencies**: `Dio`, `AuthCredentialsProvider`, `AuthSessionProvider`.

### Job Model Enhancements

#### SyncStatus Enum

Enhanced with additional states:
* `pending`: Waiting for sync to server
* `synced`: Successfully synced
* `pendingDeletion`: Marked for deletion
* `error`: Failed sync but will retry
* `failed`: Failed sync and exceeded max retry attempts

#### Job Entity

Enhanced with error recovery fields:
* `retryCount`: Number of failed sync attempts (default: 0)
* `lastSyncAttemptAt`: Timestamp of last sync attempt for backoff calculation

## Authentication and Job Operations

The job feature interacts with authentication through the `AuthSessionProvider` interface:

### Authentication Context
- Repository and services obtain the current user ID through the `AuthSessionProvider` interface
- Components verify authentication state before performing operations
- Authentication errors are translated to domain-specific `AuthFailure` objects

### Authentication Error Handling
Job operations fail cleanly when authentication is invalid:
- `JobRepositoryImpl` checks `isAuthenticated()` before proceeding with job creation
- `JobWriterService` gets the current user ID from `getCurrentUserId()` and handles authentication exceptions
- `ApiJobRemoteDataSource` verifies authentication before making API calls

### Future Authentication Integrations
The following planned authentication enhancements (see [Architecture: Authentication](./architecture-overview.md#future-authentication-enhancements)) will further improve the Job feature:

1. **Offline Authentication**: Will allow job operations to work offline with cached authentication
2. **Robust Error Recovery**: Will enable better handling of transient authentication failures during job sync
3. **Auth Event System**: Will allow job components to react to authentication state changes (logout/token expiry)

## Sync Strategy

This section details the comprehensive synchronization strategy for jobs, covering creation, updates, deletions, and error handling.

### Core Principles

1. **Server Authority ("Server Wins")**: 
   - The server is the ultimate source of truth
   - After initial sync, server data always overwrites local data
   - No conflict detection or resolution needed - server response is accepted as-is

2. **Offline-First Creation/Updates**:
   - New jobs are created locally first with client-generated UUID
   - Job updates are applied locally first
   - Both are marked with `SyncStatus.pending` until synced

### Sync Architecture

The sync process is split between two specialized services:

1. **JobSyncOrchestratorService**:
   - Decides *what* to sync and when
   - Handles concurrency with mutex lock (Default is re-entrant from `package:mutex`)
   - Collects jobs that need synchronization
   - Checks network connectivity
   * Delegating actual sync operations to processor
   * Providing API for manual reset of failed jobs

2. **JobSyncProcessorService**:
   - Performs the actual API operations
   - Updates local job state based on API responses
   - Handles error conditions and updates job status
   - Manages associated resources (e.g., audio files)

This separation of concerns allows for:
- Better testability of the orchestration logic separate from API interactions
- Clearer responsibility boundaries
- Reduced risk of race conditions

### Sync Process Details

1. **Triggering:** 
   - The `JobSyncTriggerService` performs a dual-operation sync cycle every 15 seconds:
     * PUSH: Calls `JobRepository.syncPendingJobs()` to push local changes to the server
     * PULL: Calls `JobRepository.reconcileJobsWithServer()` to detect server-side deletions
   - Both operations occur sequentially (push then pull) to ensure consistency
   - Triggers also occur on app foregrounding via lifecycle observer
   - Mutex protection prevents overlapping sync cycles
   - Compatible with platform-specific background workers

2. **Push Orchestration:** 
   - `JobSyncOrchestratorService` gathers three types of jobs to process:
     * Jobs with `SyncStatus.pending` for creation/update
     * Jobs with `SyncStatus.pendingDeletion` for deletion
     * Jobs with `SyncStatus.error` that meet retry criteria
   - For each job, it calls the appropriate processor method
   - Handles concurrency with mutex to prevent parallel sync attempts

3. **Pull Reconciliation:**
   - When fetching jobs from the server via `JobReaderService.getJobs()`:
     * Repository gets full list of jobs as `JobApiDTO` objects from API
     * Builds a `serverIdToLocalIdMap` from local synced jobs
     * Maps DTOs to Job entities using `JobMapper.fromApiDtoList()` with the ID map
     * Compares server IDs with local synced jobs to identify server deletions
     * Any jobs previously synced but missing from API response are considered deleted by server
     * These jobs are immediately deleted locally (including associated audio files)
     * This ensures the local database doesn't contain "ghost" jobs deleted on the server

4. **Retry Eligibility:**
   - Jobs are eligible for retry when:
     * `syncStatus == SyncStatus.error`
     * `retryCount < MAX_RETRY_ATTEMPTS` (default: 5)
     * Time since last attempt follows exponential backoff: `now - (baseBackoff * 2^retryCount)`
   - The `JobLocalDataSource` implements the logic for finding retry-eligible jobs

5. **Processing:**
   - `JobSyncProcessorService` handles each job based on its status:
   - **New Job Flow** (`serverId == null`, `SyncStatus.pending`):
     * Creates job on server with client-generated `localId`
     * Receives response with server-assigned `serverId`
     * Updates job with `SyncStatus.synced`
   - **Update Job Flow** (`serverId != null`, `SyncStatus.pending`):
     * Updates job on server using its `serverId`
     * Only sends changed fields
     * Updates job with `SyncStatus.synced`
   - **Delete Job Flow** (`SyncStatus.pendingDeletion`):
     * Deletes job on server (if it has a `serverId`)
     * Permanently deletes local job on success
     * Deletes associated audio file
     * **Note:** A current limitation exists with orphaned jobs (jobs with no server counterpart). When these jobs are marked for deletion, they still go through the sync process, which can result in unnecessary retry attempts when the server returns a "not found" error. A smarter deletion process is needed to identify and directly delete these orphaned jobs without server synchronization attempts.

6. **Error Handling:**
   - If an API call fails (e.g., `createJob`, `updateJob`, `deleteJob`), the `JobSyncProcessorService` catches the exception.
   - It calls `_handleSyncError` which updates the job's local state:
     - Increments `retryCount`.
     - Sets `lastSyncAttemptAt` to the current time.
     - Sets `syncStatus` to `SyncStatus.error` if retries remain.
     - Sets `syncStatus` to `SyncStatus.failed` if `retryCount` reaches `maxRetryAttempts` (currently 5).
   - The orchestrator identifies jobs in the `error` state for subsequent retry attempts based on an exponential backoff calculation.
   - **Retry Timing**: The eligibility for retry is determined by the `HiveJobLocalDataSourceImpl.getJobsToRetry` method. The backoff duration itself is calculated using the `calculateRetryBackoff` function in `lib/features/jobs/data/config/job_sync_config.dart`.
     - The formula is: `min(retryBackoffBase * pow(2, retryCount), maxBackoffDuration)`.
     - Configuration values (defined in `JobSyncConfig`):
       - `retryBackoffBase`: Currently 1 minute.
       - `maxRetryAttempts`: Currently 5.
       - `maxBackoffDuration`: Currently 1 hour (caps the exponential growth).
     - A job is only considered for retry if the current time is after its `lastSyncAttemptAt` plus the calculated backoff duration.
   - The overall sync process continues with other jobs even if one fails.

7. **Manual Reset:**
   - Jobs with `SyncStatus.failed` require manual intervention
   - UI displays failed jobs with a retry option
   - `resetFailedJob(localId)` in the `JobSyncOrchestratorService`:
     * Checks if job exists and has `SyncStatus.failed`
     * Resets to `SyncStatus.pending` with zeroed retry count
     * Returns `Right<Unit>` on success or appropriate error

### Pull Reconciliation

The `JobReaderService.getJobs()` method performs synchronization and reconciliation in the following sequence:

1. Fetch all local jobs with `SyncStatus.synced`
2. Fetch all server jobs as `JobApiDTO` objects via the API
3. Build a `serverIdToLocalIdMap` from local synced jobs
4. Map DTOs to Job entities using `JobMapper.fromApiDtoList()` with the ID map
5. Compare the collections to identify jobs present locally but missing on the server
6. For each server-deleted job, call `JobDeleterService.permanentlyDeleteJob(localId)` 
7. For each mapped remote job, save to local cache with proper localId

This reconciliation process ensures the local cache accurately reflects the server state, particularly for jobs deleted on the server, while maintaining proper ID mapping between server and local entities.

### Audio File Management

1. Audio files are stored locally when jobs are created.
2. Files remain on device as long as their associated job exists.
3. When a job is deleted (either locally initiated or server-detected), its audio file is also deleted.
4. Audio lifecycle is 100% tied to job lifecycle - when the job is gone, the audio is gone.
5. **Error Handling**:
   * All file deletion attempts are wrapped in `try-catch` blocks.
   * Path normalization and null-checking are performed before deletion.
   * If a file deletion fails, the error is logged as `ERROR` severity using the structured logging facility (`log_helpers.dart`).
   * Log entries include the job's `localId`, the full file path, and the specific error message.
   * These failures are considered non-fatal to the job deletion process itself (the job record is still removed locally).
   * A retry mechanism for failed file deletions will be implemented (e.g., on next app startup or sync cycle) to ensure eventual cleanup.

### Authentication Integration

The job synchronization system integrates closely with the authentication system via the `AuthEventBus`:

1. **JobSyncOrchestratorService** listens to the following auth events:
   * `onlineRestored`: Triggers an immediate sync
   * `offlineDetected`: Pauses sync operations
   * `loggedOut`: Stops all sync operations

2. **JobSyncAuthGate**:
   * Acts as a wrapper around `JobSyncTriggerService`
   * Ensures sync only starts after user is authenticated
   * Subscribes to auth events to:
     * Initialize sync on `loggedIn`
     * Dispose sync on `loggedOut` 
   * Waits for both authentication and first frame rendering before starting sync

3. **JobSyncTriggerService**:
   * Responsible for periodic sync timer (every 15 seconds)
   * Uses app lifecycle awareness (foreground/background) for smart timing
   * Designed for performance optimization:
     * Defers startup until after first frame is rendered
     * Only activates when user is authenticated
     * Avoids UI thread blocking during app initialization
     
This authentication integration ensures that:
* Network requests are only made when the user is authenticated
* Resources are properly cleaned up during logout
* App startup performance is optimized (no premature sync)
* The system adapts to connectivity changes

For more details on the startup performance optimizations, see [Startup Performance Optimizations](../archive/todo_done/startup-performance-unblock-todo_done.md).

## Background Processing Support

The job feature architecture is designed to work with background processing mechanisms:

1. **In-App Foreground Sync:**
   - `JobSyncTriggerService` manages a 15-second `Timer.periodic` when app is foregrounded
   - Timer is paused/resumed based on app lifecycle events
   - `JobRepositoryImpl` triggers immediate sync upon successful job creation

2. **Immediate Sync on Job Creation:**
   - After successful local job creation, `JobRepositoryImpl` immediately triggers `syncPendingJobs()`
   - This "fire-and-forget" call reduces server synchronization latency for newly created jobs
   - The sync operation runs asynchronously and doesn't block or affect the job creation result
   - Handles all error conditions gracefully, preserving the offline-first architecture

3. **Background Worker Integration:**
   - The architecture separates triggering from execution
   - Platform-specific implementations (WorkManager for Android, BackgroundTasks for iOS) can call the same `JobRepository.syncPendingJobs()` method
   - Consistent retry mechanism works regardless of what triggered the sync

4. **Lifecycle-Aware Processing:**
   - `JobSyncLifecycleObserver` manages sync state during app transitions
   - Ensures sync is running when app is visible
   - Pauses sync when app is backgrounded (unless using platform background workers)

## Remaining Improvements

The following improvements should be considered for future development:

1. **Cubit Lifecycle Management**:
   - Hoist BlocProvider instances to a higher level in the widget tree (e.g., in main.dart with MultiBlocProvider)
   - Use BlocProvider.value in child widgets to prevent recreating cubits on every rebuild
   - Ensure proper disposal at the appropriate lifecycle level to prevent memory leaks
   - This pattern prevents performance issues caused by unnecessary cubit recreation during UI rebuilds

2. **Background Sync Enhancement**:
   - Implement platform-specific background workers for sync operations when app is backgrounded
   - Add deeper offline queue capabilities with prioritization

For the detailed implementation plan, including outstanding tasks for error recovery, sync triggering, lifecycle management, concurrency protection, and logging, see the [JobRepository Refactoring Plan](../archive/jobrepo_refactor.md).

## Synchronization Flow Diagrams

To make the sync flow clear, we've split it into small, focused sequence diagrams.

### Sync Orchestration - Job Collection

This diagram shows how the orchestrator gathers jobs needing synchronization based on their status and retry eligibility.
```mermaid
sequenceDiagram
    autonumber
    participant JobRepo as JobRepositoryImpl
    participant Orchestrator as JobSyncOrchestratorService
    participant Network as NetworkInfo
    participant LocalDS as LocalDataSource
    
    Note over JobRepo, Orchestrator: Triggered by:<br/>1. Timer-based sync (15s)<br/>2. Immediate sync after job creation<br/>3. Network connectivity restored
    
    JobRepo->>Orchestrator: syncPendingJobs()
    Orchestrator->>Orchestrator: acquireLock() (mutex)
    Orchestrator->>Network: isConnected()
    Network-->>Orchestrator: true
    
    Orchestrator->>LocalDS: getJobsByStatus(SyncStatus.pending)
    LocalDS-->>Orchestrator: List<Job> pending
    
    Orchestrator->>LocalDS: getJobsByStatus(SyncStatus.pendingDeletion)
    LocalDS-->>Orchestrator: List<Job> pendingDeletion
    
    Orchestrator->>LocalDS: getJobsToRetry(maxRetries, backoff)
    LocalDS-->>Orchestrator: List<Job> retry-eligible
```

### Sync Orchestration - Delegation

This diagram illustrates the orchestrator delegating the processing of collected jobs to the appropriate processor methods.
```mermaid
sequenceDiagram
    autonumber
    participant Orchestrator as JobSyncOrchestratorService
    participant Processor as JobSyncProcessorService
    
    Note over Orchestrator: With collected jobs
    
    loop For each pending/retry job
        Orchestrator->>Processor: processJobSync(job)
        Processor-->>Orchestrator: Either<Failure, Unit>
    end
    
    loop For each pendingDeletion job
        Orchestrator->>Processor: processJobDeletion(job)
        Processor-->>Orchestrator: Either<Failure, Unit>
    end
    
    Orchestrator->>Orchestrator: releaseLock()
```

### Processor - New Job Creation 

This diagram details the flow for creating a new job on the remote server and updating the local status upon success.
```mermaid
sequenceDiagram
    autonumber
    participant Processor as JobSyncProcessorService
    participant RemoteDS as RemoteDataSource
    participant LocalDS as LocalDataSource
    participant API as REST API

    Note over Processor: New Job (serverId == null)
    
    Processor->>RemoteDS: createJob(job)
    RemoteDS->>API: POST /api/v1/jobs
    API-->>RemoteDS: Job JSON with serverId
    RemoteDS-->>Processor: Job with serverId
    
    Processor->>LocalDS: saveJob(job with SyncStatus.synced)
    LocalDS-->>Processor: Success
```

### Processor - Job Update

This diagram shows the process of sending job updates to the remote server and updating the local status.
```mermaid
sequenceDiagram
    autonumber
    participant Processor as JobSyncProcessorService
    participant RemoteDS as RemoteDataSource
    participant LocalDS as LocalDataSource
    participant API as REST API

    Note over Processor: Existing Job (serverId != null)
    
    Processor->>RemoteDS: updateJob(job)
    RemoteDS->>API: PUT /api/v1/jobs/{serverId}
    API-->>RemoteDS: Updated Job JSON
    RemoteDS-->>Processor: Updated Job
    
    Processor->>LocalDS: saveJob(job with SyncStatus.synced)
    LocalDS-->>Processor: Success
```

### Processor - Sync Error Handling

This diagram outlines how synchronization failures are handled by updating the job's retry count and status.
```mermaid
sequenceDiagram
    autonumber
    participant Processor as JobSyncProcessorService
    participant LocalDS as LocalDataSource
    participant API as REST API

    Note over Processor: API Error Path
    
    API-->>Processor: Error Response
    
    Processor->>Processor: _handleRemoteSyncFailure(job, error)
    Note over Processor: Increment retryCount, update<br/>lastSyncAttemptAt
    
    alt retryCount >= MAX_RETRIES
        Processor->>LocalDS: saveJob(with SyncStatus.failed)
    else Retries Remaining
        Processor->>LocalDS: saveJob(with SyncStatus.error)
    end
```

## Job Deletion Flow

The job deletion flow has been enhanced with a "smart delete" feature that intelligently determines the best deletion approach based on job status:

```mermaid
graph TD
    A[User Swipes to Delete Job] --> B{Smart Delete Decision}
    B -- Job has no serverId OR <br/> Confirmed non-existent on server --> C[Immediate Purge Locally]
    B -- Job exists on server OR <br/> Cannot confirm server status --> D[Mark as pendingDeletion]
    C --> E{Delete Files}
    D --> F[Standard Sync-based Deletion]
    E -- Success --> G[Job Completely Removed]
    E -- File Deletion Error --> H[Job Removed but <br/> Audio File Cleanup Failed]
    F --> I[Job Synced and <br/> Purged Eventually]
```

1. **Smart Delete Decision Point**:
   - When a user initiates job deletion (typically via swipe-to-delete), the system invokes `JobRepository.smartDeleteJob(localId)`.
   - The repository delegates to `JobDeleterService.attemptSmartDelete(localId)` which makes an intelligent decision:
     
     a. **Orphan Check**: If the job has no `serverId` (never synced) or empty `serverId`, it's an orphan with no server record to delete.
     
     b. **Server Existence Check**: If the job has a `serverId`, the system performs a lightweight server check (HEAD or GET request with 2-second timeout) to confirm if the job still exists server-side.
     
     c. **Offline/Error Handling**: If the device is offline, network check fails, or a timeout occurs, the system falls back to the standard deletion flow for safety.

2. **Immediate Purge Path**:
   - For confirmed orphans (no serverId or 404 server response), the system calls `permanentlyDeleteJob(localId)`.
   - This immediately removes the job from the local database without sync.
   - Associated resources like audio files are also cleaned up.
   - The job disappears from the UI immediately, improving perceived responsiveness.
   - Returns `Right(true)` to indicate immediate purging occurred.

3. **Standard Deletion Path**:
   - For jobs that exist on the server (or cannot be confirmed as non-existent), the system calls `deleteJob(localId)`.
   - This marks the job with `SyncStatus.pendingDeletion` for deletion during next sync.
   - The job remains in local storage until successfully deleted on the server.
   - The UI typically shows this job with a "pending deletion" state.
   - Returns `Right(false)` to indicate standard sync deletion was used.

### Smart Delete Technical Details

The implementation in `JobDeleterService.attemptSmartDelete()` includes:

1. **Server Existence Check**:
   - For jobs with a serverId, a lightweight request checks if the job exists on the server.
   - Uses a short 2-second timeout to prevent UI lag.
   - Only performed when online and when the necessary dependencies (NetworkInfo, RemoteDataSource) are available.

2. **Decision Logic**:
   - Jobs with null or empty `serverId` are immediately purged.
   - Jobs that return HTTP 404 from the server are immediately purged.
   - Jobs that return HTTP 200 are marked for standard sync-based deletion.
   - Jobs with server connectivity issues, timeouts, or other errors are marked for standard sync-based deletion for safety.

3. **Error Handling**:
   - Network failures or timeouts during existence check fail safely to standard deletion.
   - Job not found locally returns appropriate CacheFailure.
   - The implementation is resilient to various error conditions including API exceptions, network issues, and timeouts.

This enhancement significantly improves user experience for orphaned jobs by making their deletion feel instant, while maintaining the robust sync-based deletion for server-synchronized jobs.