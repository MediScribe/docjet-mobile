# Mermaid Theme Testing - Realistic Examples

This document contains realistic diagrams styled with different approaches to ensure visibility in both light and dark modes.

## High-Level Architecture Diagram (Flowchart)

**Current Test: Absolute Default Rendering (No Theme, No Custom Styling)**

```mermaid
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
```

## Job Data Layer Flow (Sequence Diagram)

**Current Test: Absolute Default Rendering (No Theme, No Custom Styling)**

```mermaid
sequenceDiagram
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