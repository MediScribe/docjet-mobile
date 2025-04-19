# Job Data Layer Flow

This document details the data flow architecture for the Job feature in DocJet Mobile.

> **TLDR:** This is an offline-first architecture with server-side synchronization. Jobs have a dual-ID system (client-generated UUID and server-assigned ID), undergo local-first CRUD operations, are synchronized on a 15-second interval, and can handle network failures with appropriate status tracking. Historical development details can be found in [job_dataflow_development_history.md](./job_dataflow_development_history.md).

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
   * Improved testability with focused components

8. **Background Processing Support**
   * Explicit sync triggering mechanism
   * App lifecycle aware (foreground/background transitions)
   * Compatible with platform-specific background workers

## Job Feature Architecture Overview

The following diagram illustrates the components and their relationships for the job feature.

```mermaid
graph TD
    subgraph "Presentation Layer (UI, State Management)"
        UI --> |Uses| AppService(Application Service / Use Cases)
    end

    subgraph "Domain Layer (Core Logic, Entities)"
        AppService -->|Uses| JobRepositoryInterface(JobRepository Interface)
        JobEntity((Job Entity<br>- Pure Dart<br>- Equatable))
        JobRepositoryInterface -- Defines --> JobEntity
    end

    subgraph "Data Layer (Implementation Details)"
        JobRepositoryImpl(JobRepositoryImpl<br>- Delegates to Services) -->|Implements| JobRepositoryInterface

        subgraph "Service Layer"
            ReaderService(JobReaderService<br>- Read Operations)
            WriterService(JobWriterService<br>- Write Operations)
            DeleterService(JobDeleterService<br>- Delete Operations)
            SyncService(JobSyncService<br>- Sync Operations)
            SyncTrigger(JobSyncTriggerService<br>- 15s Timer & Lifecycle)
            
            SyncTrigger -->|Calls| SyncService
        end

        JobRepositoryImpl -->|Uses| ReaderService
        JobRepositoryImpl -->|Uses| WriterService
        JobRepositoryImpl -->|Uses| DeleterService
        JobRepositoryImpl -->|Uses| SyncService

        subgraph "Infrastructure & Data Sources"
            LocalDS[JobLocalDataSource]
            RemoteDS[JobRemoteDataSource]
            Network[NetworkInfo]
            UUID[UuidGenerator]
            FileSystem[FileSystem]
        end

        ReaderService -->|Uses| LocalDS
        ReaderService -->|Uses| RemoteDS
        
        WriterService -->|Uses| LocalDS
        WriterService -->|Uses| UUID
        
        DeleterService -->|Uses| LocalDS
        DeleterService -->|Uses| FileSystem
        
        SyncService -->|Uses| LocalDS
        SyncService -->|Uses| RemoteDS
        SyncService -->|Uses| Network
        SyncService -->|Uses| FileSystem

        subgraph "Local Persistence (Hive)"
            HiveJobLocalDS(HiveJobLocalDataSourceImpl) -->|Implements| LocalDS
            HiveJobLocalDS -->|Uses| JobMapper(JobMapper)
            HiveJobLocalDS -->|Uses| HiveBox([Hive Box])
            JobMapper -->|Maps to/from| JobHiveModel((JobHiveModel DTO<br>- Hive Annotations))
            JobMapper -->|Maps to/from| JobEntity
            JobHiveModel -- Stored in --> HiveBox
        end

        subgraph "Remote API"
            ApiJobRemoteDS(ApiJobRemoteDataSourceImpl) -->|Implements| RemoteDS
            ApiJobRemoteDS -->|Uses| HttpClient([HTTP Client<br>- dio/http])
            ApiJobRemoteDS -->|Uses| JobMapper
            ApiJobRemoteDS -->|Uses| JobApiDTO((JobApiDTO<br>- API Contract))
            JobMapper -->|Maps to/from| JobApiDTO
            ApiJobRemoteDS -->|Talks to| RestAPI{REST API<br>/api/v1/jobs}
            JobApiDTO -->|Serializes/Deserializes| RestAPI
        end
    end

    %% Styling for clarity with improved contrast
    classDef invisible fill:none,stroke:none;
    classDef domain fill:#E64A45,stroke:#222,stroke-width:2px,color:#fff,padding:15px;
    classDef service fill:#6E9E28,stroke:#222,stroke-width:2px,color:#fff;
    classDef data fill:#4285F4,stroke:#222,stroke-width:2px,color:#fff;
    classDef presentation fill:#0F9D58,stroke:#222,stroke-width:2px,color:#fff;

    class JobEntity,JobRepositoryInterface domain;
    class ReaderService,WriterService,DeleterService,SyncService,SyncTrigger service;
    class JobRepositoryImpl,LocalDS,RemoteDS,HiveJobLocalDS,ApiJobRemoteDS,JobMapper,JobHiveModel,JobApiDTO,HiveBox,HttpClient,RestAPI,Network,UUID,FileSystem data;
    class UI,AppService presentation;
```

## Job Data Layer Flow

This sequence diagram shows the typical flows when the application requests job data, demonstrating how the repository interacts with local and remote data sources.

```mermaid
%%{init: {'theme': 'base', 'themeVariables': { 
  'primaryColor': '#E64A45', 
  'primaryTextColor': '#fff', 
  'primaryBorderColor': '#222', 
  'lineColor': '#4285F4', 
  'secondaryColor': '#0F9D58', 
  'tertiaryColor': '#9E9E9E',
  'actorLineColor': '#e0e0e0',
  'noteBkgColor': '#8C5824',      
  'noteTextColor': '#fff'       
}}}%%
sequenceDiagram
    participant AppSvc as Application Service
    participant JobRepo as JobRepositoryImpl
    participant ReaderSvc as JobReaderService
    participant LocalDS as HiveJobLocalDS
    participant RemoteDS as ApiJobRemoteDS
    participant Mapper as JobMapper
    participant ApiDTO as JobApiDTO
    participant Hive as Hive Box
    participant API as REST API

    Note over AppSvc, API: Fetching Job List

    %% Success Path - Local Data
    rect rgb(15, 157, 88, 0.2)
    Note over AppSvc, API: Success Path - Local Cache Hit
    AppSvc->>JobRepo: getJobs()
    JobRepo->>ReaderSvc: getJobs()
    ReaderSvc->>LocalDS: getJobs()
    LocalDS->>Hive: readAllJobs()
    Hive-->>LocalDS: List<JobHiveModel> (fresh data)
    LocalDS->>Mapper: fromHiveModelList(hiveModels)
    Mapper-->>LocalDS: List<JobEntity>
    LocalDS-->>ReaderSvc: List<JobEntity>
    ReaderSvc-->>JobRepo: Right<List<JobEntity>>
    JobRepo-->>AppSvc: Right<List<JobEntity>>
    end
    
    %% Refresh Path - Remote Fetch
    rect rgb(66, 133, 244, 0.2)
    Note over AppSvc, API: Refresh Path - Local Cache Miss/Stale
    AppSvc->>JobRepo: getJobs()
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
    JobRepo-->>AppSvc: Right<List<JobEntity>>
    end
    
    %% Error Path
    rect rgb(230, 162, 60, 0.2)
    Note over AppSvc, API: Error Path - Network/Server Failure
    AppSvc->>JobRepo: getJobs()
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
    JobRepo-->>AppSvc: Left<Failure>
    end
```

## Job Creation, Update, and Sync Flow

This sequence diagram illustrates the data flow for creating new jobs, updating existing jobs, and synchronizing pending changes with the backend.

```mermaid
%%{init: {'theme': 'base', 'themeVariables': { 
  'primaryColor': '#E64A45', 
  'primaryTextColor': '#fff', 
  'primaryBorderColor': '#222', 
  'lineColor': '#4285F4', 
  'secondaryColor': '#0F9D58', 
  'tertiaryColor': '#9E9E9E',
  'actorLineColor': '#e0e0e0',
  'noteBkgColor': '#8C5824',      
  'noteTextColor': '#fff'       
}}}%%
sequenceDiagram
    participant AppSvc as Application Service
    participant JobRepo as JobRepositoryImpl
    participant WriterSvc as JobWriterService
    participant DeleterSvc as JobDeleterService
    participant SyncSvc as JobSyncService
    participant LocalDS as HiveJobLocalDS
    participant RemoteDS as ApiJobRemoteDS
    participant Mapper as JobMapper
    participant UUID as UUID Generator
    participant Hive as Hive Box
    participant API as REST API
    participant FileSystem as File System

    %% Job Creation Flow
    rect rgb(15, 157, 88, 0.2)
    Note over AppSvc, API: Job Creation - Local First
    AppSvc->>JobRepo: createJob(audioFilePath, text)
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
    JobRepo-->>AppSvc: Right<Job>
    end
    
    %% Job Update Flow
    rect rgb(230, 77, 69, 0.2)
    Note over AppSvc, API: Job Update - Local First
    AppSvc->>JobRepo: updateJob(localId, updates)
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
    
    JobRepo-->>AppSvc: Right<Job>
    end
    
    %% Job Deletion Flow
    rect rgb(241, 156, 31, 0.2)
    Note over AppSvc, API: Job Deletion - Local First
    AppSvc->>JobRepo: deleteJob(localId)
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
    JobRepo-->>AppSvc: Right<Unit>
    end
    
    %% Sync Pending Jobs Flow with Error Recovery
    rect rgb(66, 133, 244, 0.2)
    Note over AppSvc, API: Sync Pending Jobs (15-Second Timer)
    
    Note over SyncSvc: Timer triggers syncPendingJobs()
    JobRepo->>SyncSvc: syncPendingJobs()
    
    SyncSvc->>LocalDS: getJobsByStatus(SyncStatus.pending)
    LocalDS->>Hive: Query for SyncStatus.pending
    Hive-->>LocalDS: List<JobHiveModel>
    LocalDS->>Mapper: fromHiveModelList(models)
    Mapper-->>LocalDS: List<Job>
    LocalDS-->>SyncSvc: List<Job> with pending status
    
    SyncSvc->>LocalDS: getJobsByStatus(SyncStatus.pendingDeletion)
    LocalDS->>Hive: Query for SyncStatus.pendingDeletion
    Hive-->>LocalDS: List<JobHiveModel>
    LocalDS->>Mapper: fromHiveModelList(models)
    Mapper-->>LocalDS: List<Job>
    LocalDS-->>SyncSvc: List<Job> with pendingDeletion status
    
    SyncSvc->>LocalDS: getJobsToRetry(maxRetries, backoffDuration)
    LocalDS->>Hive: Query jobs with error status eligible for retry
    Note over LocalDS, Hive: Filter by retryCount < maxRetries and<br/>lastSyncAttemptAt < now-backoff
    Hive-->>LocalDS: List<JobHiveModel>
    LocalDS->>Mapper: fromHiveModelList(models)
    Mapper-->>LocalDS: List<Job>
    LocalDS-->>SyncSvc: List<Job> eligible for retry
    
    Note over SyncSvc: Combine all jobs that need syncing
    
    loop For each pending job (including retry-eligible)
        SyncSvc->>SyncSvc: syncSingleJob(job)
        
        alt Job has SyncStatus.pending
            SyncSvc->>SyncSvc: Check serverId field
            
            alt serverId == null (New Job)
                SyncSvc->>RemoteDS: createJob(job)
                RemoteDS->>API: POST /api/v1/jobs with audio upload
                
                alt API Success
                    API-->>RemoteDS: Job JSON with server ID
                    RemoteDS-->>SyncSvc: Job with serverId
                    
                    SyncSvc->>LocalDS: saveJob(syncedJob with SyncStatus.synced)
                    LocalDS->>Hive: Save updated job
                    Hive-->>LocalDS: Success
                    LocalDS-->>SyncSvc: Success
                else API Error
                    API-->>RemoteDS: Error Response
                    RemoteDS-->>SyncSvc: Exception
                    
                    SyncSvc->>SyncSvc: Increment retryCount, update lastSyncAttemptAt
                    SyncSvc->>SyncSvc: Check if retryCount >= MAX_RETRIES
                    
                    alt Max Retries Exceeded
                        SyncSvc->>LocalDS: saveJob(job with SyncStatus.failed)
                    else Retries Remaining
                        SyncSvc->>LocalDS: saveJob(job with SyncStatus.error)
                    end
                    
                    LocalDS->>Hive: Save job with updated status
                    Hive-->>LocalDS: Success
                    LocalDS-->>SyncSvc: Success
                end
                
            else serverId != null (Update)
                SyncSvc->>RemoteDS: updateJob(job)
                RemoteDS->>API: PATCH/PUT /api/v1/jobs/{serverId}
                
                alt API Success
                    API-->>RemoteDS: Updated Job JSON
                    RemoteDS-->>SyncSvc: Updated Job
                    
                    SyncSvc->>LocalDS: saveJob(syncedJob with SyncStatus.synced)
                    LocalDS->>Hive: Save updated job
                    Hive-->>LocalDS: Success
                    LocalDS-->>SyncSvc: Success
                else API Error
                    API-->>RemoteDS: Error Response
                    RemoteDS-->>SyncSvc: Exception
                    
                    SyncSvc->>SyncSvc: Increment retryCount, update lastSyncAttemptAt
                    SyncSvc->>SyncSvc: Check if retryCount >= MAX_RETRIES
                    
                    alt Max Retries Exceeded
                        SyncSvc->>LocalDS: saveJob(job with SyncStatus.failed)
                    else Retries Remaining
                        SyncSvc->>LocalDS: saveJob(job with SyncStatus.error)
                    end
                    
                    LocalDS->>Hive: Save job with updated status
                    Hive-->>LocalDS: Success
                    LocalDS-->>SyncSvc: Success
                end
            end
            
        else Job has SyncStatus.pendingDeletion
            alt serverId != null
                SyncSvc->>RemoteDS: deleteJob(job.serverId)
                RemoteDS->>API: DELETE /api/v1/jobs/{serverId}
                alt API Success
                    API-->>RemoteDS: Success response
                    RemoteDS-->>SyncSvc: Success
                else API Error
                    API-->>RemoteDS: Error Response
                    RemoteDS-->>SyncSvc: Exception
                    
                    SyncSvc->>SyncSvc: Increment retryCount, update lastSyncAttemptAt
                    SyncSvc->>SyncSvc: Check if retryCount >= MAX_RETRIES
                    
                    alt Max Retries Exceeded
                        SyncSvc->>LocalDS: saveJob(job with SyncStatus.failed)
                        LocalDS->>Hive: Save job with updated status
                        Hive-->>LocalDS: Success
                        LocalDS-->>SyncSvc: Success
                        Note over SyncSvc: Skip deletion for now
                    else Retries Remaining
                        SyncSvc->>LocalDS: saveJob(job with SyncStatus.error)
                        LocalDS->>Hive: Save job with updated status
                        Hive-->>LocalDS: Success
                        LocalDS-->>SyncSvc: Success
                        Note over SyncSvc: Skip deletion for now
                    end
                end
            else serverId == null (local-only job)
                Note over SyncSvc: Skip API call for jobs never synced to server
            end
            
            alt Successful API call or local-only job
                SyncSvc->>SyncSvc: permanentlyDeleteJob(job.localId)
                SyncSvc->>LocalDS: deleteJob(job.localId)
                LocalDS->>Hive: Delete from Hive Box
                Hive-->>LocalDS: Delete Confirmation
                LocalDS-->>SyncSvc: Success
                
                alt Job has audioFilePath
                    SyncSvc->>FileSystem: deleteFile(audioFilePath)
                    alt File Deletion Success
                        FileSystem-->>SyncSvc: Success
                    else File Deletion Error
                        FileSystem-->>SyncSvc: Error (logged but not fatal)
                    end
                end
            end
        end
    end
    
    SyncSvc-->>JobRepo: Right<Unit>
    end
    
    %% Manual Failed Job Reset Flow
    rect rgb(142, 68, 173, 0.2)
    Note over AppSvc, API: Manual Reset of Failed Job
    
    AppSvc->>JobRepo: resetFailedJob(localId)
    JobRepo->>SyncSvc: resetFailedJob(localId)
    SyncSvc->>LocalDS: getJobById(localId)
    LocalDS->>Hive: Read from Hive Box
    Hive-->>LocalDS: JobHiveModel
    LocalDS->>Mapper: fromHiveModel(model)
    Mapper-->>LocalDS: Job
    LocalDS-->>SyncSvc: Job
    
    alt Job has SyncStatus.failed
        SyncSvc->>SyncSvc: Reset job to pending state
        SyncSvc->>LocalDS: saveJob(job with:<br/>- SyncStatus.pending<br/>- retryCount = 0<br/>- lastSyncAttemptAt = null)
        LocalDS->>Hive: Save reset job
        Hive-->>LocalDS: Success
        LocalDS-->>SyncSvc: Success
        SyncSvc-->>JobRepo: Right<Job>
        JobRepo-->>AppSvc: Right<Job>
    else Job not in failed state
        SyncSvc-->>JobRepo: Left<InvalidOperationFailure>
        JobRepo-->>AppSvc: Left<InvalidOperationFailure>
    end
    end
    
    %% Server-Side Deletion Detection
    rect rgb(94, 53, 177, 0.2)
    Note over AppSvc, API: Server-Side Deletion Detection
    AppSvc->>JobRepo: getJobs() (refresh)
    JobRepo->>ReaderSvc: getJobs()
    ReaderSvc->>RemoteDS: fetchJobs()
    RemoteDS->>API: GET /api/v1/jobs
    API-->>RemoteDS: List of current jobs
    RemoteDS-->>ReaderSvc: List<Job> with serverIds
    
    ReaderSvc->>LocalDS: getJobsByStatus(SyncStatus.synced)
    LocalDS->>Hive: Query jobs with SyncStatus.synced and serverId != null
    Hive-->>LocalDS: List<JobHiveModel>
    LocalDS->>Mapper: fromHiveModelList(models)
    Mapper-->>LocalDS: List<Job>
    LocalDS-->>ReaderSvc: List<Job> that were previously synced
    
    ReaderSvc->>ReaderSvc: Find jobs with serverId not in server response
    
    loop For each job missing from server
        ReaderSvc->>DeleterSvc: permanentlyDeleteJob(job.localId)
        DeleterSvc->>LocalDS: deleteJob(job.localId)
        LocalDS->>Hive: Delete from Hive Box
        Hive-->>LocalDS: Delete Confirmation
        LocalDS-->>DeleterSvc: Success
        
        alt Job has audioFilePath
            DeleterSvc->>FileSystem: deleteFile(audioFilePath)
            alt File Deletion Success
                FileSystem-->>DeleterSvc: Success
            else File Deletion Error
                FileSystem-->>DeleterSvc: Error (logged but not fatal)
            end
        end
        DeleterSvc-->>ReaderSvc: Success
    end
    
    ReaderSvc->>LocalDS: saveJobs(serverJobs)
    LocalDS->>Mapper: toHiveModelList(jobs)
    Mapper-->>LocalDS: List<JobHiveModel>
    LocalDS->>Hive: Save/update jobs from server
    Hive-->>LocalDS: Save Confirmation
    LocalDS-->>ReaderSvc: Success
    
    ReaderSvc-->>JobRepo: Right<List<Job>>
    JobRepo-->>AppSvc: Right<List<Job>>
    end
```

## Job Data Layer Components

### Service-Oriented Repository Pattern

The job feature implements a service-oriented repository pattern with specialized services for different operations.

#### JobRepository Interface

The public contract for job operations that feature modules interact with. It defines all operations without exposing implementation details.

Key methods:
* Read: `getJobs()`, `getJobById(localId)`
* Write: `createJob(audioFilePath, text)`, `updateJob(localId, updates)`
* Delete: `deleteJob(localId)`
* Sync: `syncPendingJobs()`, `syncSingleJob(job)`, `resetFailedJob(localId)`

#### JobRepositoryImpl

Lightweight implementation that delegates to specialized services:

```dart
class JobRepositoryImpl implements JobRepository {
  final JobReaderService _readerService;
  final JobWriterService _writerService;
  final JobDeleterService _deleterService;
  final JobSyncService _syncService;
  
  // Methods delegate directly to appropriate service
  Future<Either<Failure, List<Job>>> getJobs() => _readerService.getJobs();
  // Other methods follow the same pattern...
}
```

#### JobReaderService

Handles all read operations related to jobs.

Key features:
* Getting jobs from local storage
* Fetching jobs from remote API when needed
* Detecting server-side deletions

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

#### JobSyncService

Handles synchronization between local and remote storage.

Key features:
* Processing different sync paths (create/update/delete)
* Error handling with retry mechanism
* Exponential backoff for failed operations

#### JobSyncTriggerService

Manages periodic sync operation triggered by timer or app lifecycle events.

Key features:
* 15-second periodic timer for sync
* App lifecycle awareness (background/foreground)
* Error handling for sync operation

### Data Sources

#### JobLocalDataSource

Interface defining operations for local storage of jobs. Implemented by `HiveJobLocalDataSourceImpl`.

New methods added for error recovery:
* `getJobsToRetry(maxRetries, backoffDuration)`: Gets jobs eligible for retry based on retry count and backoff time

#### JobRemoteDataSource

Interface for remote API operations. Implemented by `ApiJobRemoteDataSourceImpl`.

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

### Sync Process Details

1. **Triggering:** 
   - The `JobSyncTriggerService` calls `JobRepository.syncPendingJobs()` every 15 seconds
   - Triggers also occur on app foregrounding via lifecycle observer
   - Compatible with platform-specific background workers

2. **Identify Pending:** 
   - `JobSyncService` gathers three types of jobs to process:
     * Jobs with `SyncStatus.pending` for creation/update
     * Jobs with `SyncStatus.pendingDeletion` for deletion
     * Jobs with `SyncStatus.error` that meet retry criteria

3. **Retry Eligibility:**
   - Jobs are eligible for retry when:
     * `syncStatus == SyncStatus.error`
     * `retryCount < MAX_RETRY_ATTEMPTS` (default: 5)
     * Time since last attempt follows exponential backoff: `now - (baseBackoff * 2^retryCount)`

4. **Sync Logic:**
   - `JobSyncService` processes each job independently based on its status
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

5. **Error Handling:**
   - When a sync operation fails:
     * Increments `retryCount`
     * Updates `lastSyncAttemptAt` to current time
     * Sets `syncStatus = SyncStatus.error` if retries remain
     * Sets `syncStatus = SyncStatus.failed` if max retries exceeded
   - Processing continues with other jobs even if one fails

6. **Manual Reset:**
   - Jobs with `SyncStatus.failed` require manual intervention
   - UI displays failed jobs with a retry option
   - `resetFailedJob(localId)` resets the job to `SyncStatus.pending` with zeroed retry count

### Server-Side Deletion Handling

When fetching jobs from the server:
1. Repository gets full list of jobs from API
2. Compares with local jobs that have `syncStatus.synced` (ignoring pending ones)
3. Any jobs previously synced but missing from API response are considered deleted by server
4. These jobs are immediately deleted locally (including associated audio files)

> **IMPORTANT:** Jobs with `SyncStatus.pending`, `SyncStatus.pendingDeletion`, `SyncStatus.error`, or `SyncStatus.failed` are intentionally ignored during this check to prevent accidental deletion of jobs that have not yet successfully synced to the server.

### Audio File Management

1. Audio files are stored locally when jobs are created
2. Files remain on device as long as their associated job exists
3. When a job is deleted (either locally initiated or server-detected), its audio file is also deleted
4. Audio lifecycle is 100% tied to job lifecycle - when the job is gone, the audio is gone

## Background Processing Support

The job feature architecture is designed to work with background processing mechanisms:

1. **In-App Foreground Sync:**
   - `JobSyncTriggerService` manages a 15-second `Timer.periodic` when app is foregrounded
   - Timer is paused/resumed based on app lifecycle events

2. **Background Worker Integration:**
   - The architecture separates triggering from execution
   - Platform-specific implementations (WorkManager for Android, BackgroundTasks for iOS) can call the same `JobRepository.syncPendingJobs()` method
   - Consistent retry mechanism works regardless of what triggered the sync

3. **Lifecycle-Aware Processing:**
   - `JobSyncLifecycleObserver` manages sync state during app transitions
   - Ensures sync is running when app is visible
   - Pauses sync when app is backgrounded (unless using platform background workers)

## Remaining Improvements

The detailed implementation plan, including outstanding tasks for error recovery, sync triggering, lifecycle management, concurrency protection, and logging, can be found in the [JobRepository Refactoring Plan](./jobrepo_refactor.md). 