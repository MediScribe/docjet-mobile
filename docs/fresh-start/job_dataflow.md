# Job Data Layer Flow

This document details the data flow architecture for the Job feature in DocJet Mobile.

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
        JobRepositoryImpl(JobRepositoryImpl<br>Implements JobRepository<br>Orchestrates Sync) -->|Implements| JobRepositoryInterface
        JobRepositoryImpl -->|Depends on| JobLocalDSInterface(JobLocalDataSource Interface)
        JobRepositoryImpl -->|Depends on| JobRemoteDSInterface(JobRemoteDataSource Interface)

        subgraph "Local Persistence (Hive)"
            HiveJobLocalDS(HiveJobLocalDataSourceImpl<br>- Implements JobLocalDSInterface) -->|Implements| JobLocalDSInterface
            HiveJobLocalDS -->|Uses| JobMapper(JobMapper)
            HiveJobLocalDS -->|Uses| HiveBox([Hive Box])
            JobMapper -->|Maps to/from| JobHiveModel((JobHiveModel DTO<br>- Hive Annotations))
            JobMapper -->|Maps to/from| JobEntity
            JobHiveModel -- Stored in --> HiveBox
        end

        subgraph "Remote API"
            ApiJobRemoteDS(ApiJobRemoteDataSourceImpl<br>- Implements JobRemoteDSInterface) -->|Implements| JobRemoteDSInterface
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
    classDef data fill:#4285F4,stroke:#222,stroke-width:2px,color:#fff;
    classDef presentation fill:#0F9D58,stroke:#222,stroke-width:2px,color:#fff;

    class JobEntity,JobRepositoryInterface domain;
    class JobRepositoryImpl,JobLocalDSInterface,JobRemoteDSInterface,HiveJobLocalDS,ApiJobRemoteDS,JobMapper,JobHiveModel,JobApiDTO,HiveBox,HttpClient,RestAPI data;
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
    JobRepo->>LocalDS: getLocalJobs()
    LocalDS->>Hive: readAllJobs()
    Hive-->>LocalDS: List<JobHiveModel> (fresh data)
    LocalDS->>Mapper: fromHiveModelList(hiveModels)
    Mapper-->>LocalDS: List<JobEntity>
    LocalDS-->>JobRepo: List<JobEntity>
    JobRepo-->>AppSvc: List<JobEntity>
    end
    
    %% Refresh Path - Remote Fetch
    rect rgb(66, 133, 244, 0.2)
    Note over AppSvc, API: Refresh Path - Local Cache Miss/Stale
    AppSvc->>JobRepo: getJobs()
    JobRepo->>LocalDS: getLocalJobs()
    LocalDS->>Hive: readAllJobs()
    Hive-->>LocalDS: Empty or stale data
    LocalDS-->>JobRepo: Empty List or Stale Indicator
    JobRepo->>RemoteDS: fetchRemoteJobs()
    RemoteDS->>API: GET /api/v1/jobs
    API-->>RemoteDS: Job JSON Array
    RemoteDS->>ApiDTO: fromJson(jsonData)
    ApiDTO-->>RemoteDS: List<JobApiDTO>
    RemoteDS->>Mapper: fromApiDtoList(jobApiDtos)
    Mapper-->>RemoteDS: List<JobEntity>
    RemoteDS-->>JobRepo: List<JobEntity>
    JobRepo->>LocalDS: saveJobs(fetchedJobs)
    LocalDS->>Mapper: toHiveModelList(jobEntities)
    Mapper-->>LocalDS: List<JobHiveModel>
    LocalDS->>Hive: writeAllJobs(hiveModels)
    Hive-->>LocalDS: Save Confirmation
    LocalDS-->>JobRepo: Save Confirmation
    JobRepo-->>AppSvc: List<JobEntity> (from remote)
    end
    
    %% Error Path
    rect rgb(230, 162, 60, 0.2)
    Note over AppSvc, API: Error Path - Network/Server Failure
    AppSvc->>JobRepo: getJobs()
    JobRepo->>LocalDS: getLocalJobs()
    LocalDS->>Hive: readAllJobs()
    Hive-->>LocalDS: Empty or stale data
    LocalDS-->>JobRepo: Empty List or Stale Indicator
    JobRepo->>RemoteDS: fetchRemoteJobs()
    RemoteDS->>API: GET /api/v1/jobs
    API-->>RemoteDS: Error Response (5xx, network error)
    RemoteDS-->>JobRepo: Exception/Error
    JobRepo-->>AppSvc: Error or Fallback to Stale Data
    end
```

## Job Data Layer Components

### JobRepositoryImpl
Orchestrates data operations for Jobs. It decides whether to fetch from the local cache or the remote API, and handles the synchronization between them. Implements the `JobRepositoryInterface`.

### HiveJobLocalDataSourceImpl
Implements the `JobLocalDataSourceInterface`. Responsible for interacting with the local persistence layer (Hive). Uses `JobMapper` to convert between `JobEntity` and `JobHiveModel`.

### ApiJobRemoteDataSourceImpl
Implements the `JobRemoteDataSourceInterface`. Responsible for communicating with the backend REST API (`/api/v1/jobs`) using an HTTP client. Uses `JobApiDTO` for parsing API responses and `JobMapper` for converting between `JobApiDTO` and `JobEntity`.

### JobMapper
Bidirectional mapper that handles transformations between:
- `JobEntity` (domain) and `JobHiveModel` (local persistence)
- `JobEntity` (domain) and `JobApiDTO` (API communication)

### JobApiDTO
Data Transfer Object specifically for API communication. Mirrors the API's JSON structure and handles serialization/deserialization.

### Hive Box
The Hive database box used for local storage.

### REST API
The backend endpoint providing job data.

## Implementation Status & TODOs

This section tracks the current implementation status of components in the Jobs feature.

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

### TODO Components
- ❌ **HIGH PRIORITY** - Create and implement JobRepositoryImpl (lib/features/jobs/data/repositories/job_repository_impl.dart)
  - File does not exist yet.
  - Should orchestrate between local and remote data sources
  - Implement caching strategy (freshness policy, offline support)

- ✅ **COMPLETED** - Extend JobMapper with API DTO support (lib/features/jobs/data/mappers/job_mapper.dart)
  - Implemented `fromApiDto` and `toApiDto`
  - Implemented `fromApiDtoList`
  - Skipped `toApiDtoList` as likely not needed for batch updates

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
- ❌ **REFACTOR (Debt)** - Refactor `status` fields (`Job.status`, `JobHiveModel.status`, `JobApiDTO.jobStatus`) to use a type-safe `JobStatus` enum instead of `String` to prevent runtime errors from typos and improve clarity. This requires changes in entity, models, DTO, mapper, and potentially repository/datasources depending on logic.

### Current Implementation Progress

The `JobRepositoryImpl` has been created with basic caching and staleness check strategy. To complete the implementation, the following steps are needed:

1. ❌ **HIGH PRIORITY** - Update `JobLocalDataSource` interface to include timestamp methods:
   - Add `Future<DateTime?> getLastFetchTime();` - Returns when data was last fetched from remote
   - Add `Future<void> saveLastFetchTime(DateTime time);` - Records when data was fetched

2. ❌ **HIGH PRIORITY** - Implement these methods in `HiveJobLocalDataSourceImpl`:
   - Store fetch timestamp in a dedicated Hive key or separate box
   - Handle null cases for first-time access

3. ❌ **HIGH PRIORITY** - Regenerate test mocks after interface update:
   - Run `flutter pub run build_runner build --delete-conflicting-outputs`

Once completed, the repository will properly handle:
- Cache freshness with configurable staleness threshold (default: 1 hour)
- Fetch from remote when local data is stale
- Proper error handling with logging
- Write-through caching (saves remote data locally) 