# Job Feature Architecture

```mermaid
graph TD
    subgraph "Presentation Layer (UI, State Management)"
        UI -->|Uses| AppService(Application Service / Use Cases)
    end

    subgraph "Domain Layer (Core Logic, Entities)"
        AppService -->|Uses| JobRepositoryInterface(JobRepository Interface)
        JobEntity((Job Entity\n- Pure Dart\n- Equatable))
        JobRepositoryInterface -- Defines --> JobEntity
    end

    subgraph "Data Layer (Implementation Details)"
        JobRepositoryImpl(JobRepositoryImpl\n- Implements JobRepository\n- Orchestrates Sync) -->|Uses| JobRepositoryInterface
        JobRepositoryImpl -->|Depends on| JobLocalDSInterface(JobLocalDataSource Interface)
        JobRepositoryImpl -->|Depends on| JobRemoteDSInterface(JobRemoteDataSource Interface)

        subgraph "Local Persistence (Hive)"
            HiveJobLocalDS(HiveJobLocalDataSourceImpl\n- Implements JobLocalDSInterface) -->|Uses| JobLocalDSInterface
            HiveJobLocalDS -->|Uses| JobMapper(JobMapper)
            HiveJobLocalDS -->|Uses| HiveBox([Hive Box])
            JobMapper -->|Maps to/from| JobHiveModel((JobHiveModel DTO\n- Hive Annotations))
            JobMapper -->|Maps to/from| JobEntity
            JobHiveModel -- Stored in --> HiveBox
        end

        subgraph "Remote API"
            ApiJobRemoteDS(ApiJobRemoteDataSourceImpl\n- Implements JobRemoteDSInterface) -->|Uses| JobRemoteDSInterface
            ApiJobRemoteDS -->|Uses| HttpClient([HTTP Client\n- dio/http])
            ApiJobRemoteDS -->|Talks to| RestAPI{REST API\n/api/v1/jobs}
            %% ApiJobRemoteDS -->|Maps JSON to/from| JobEntity %% Potentially needs ApiDTO later
        end
    end

    %% Styling for clarity
    classDef domain fill:#f9f,stroke:#333,stroke-width:2px;
    classDef data fill:#ccf,stroke:#333,stroke-width:2px;
    classDef presentation fill:#cfc,stroke:#333,stroke-width:2px;

    class JobEntity,JobRepositoryInterface domain;
    class JobRepositoryImpl,JobLocalDSInterface,JobRemoteDSInterface,HiveJobLocalDS,ApiJobRemoteDS,JobMapper,JobHiveModel,HiveBox,HttpClient,RestAPI data;
    class UI,AppService presentation;

``` 