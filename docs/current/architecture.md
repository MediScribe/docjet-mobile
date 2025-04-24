# DocJet Mobile Architecture

This document provides an overview of the DocJet Mobile application architecture.

## Table of Contents

1. [Architectural Principles](#architectural-principles)
2. [Layered Architecture](#layered-architecture)
3. [Feature Architectures](#feature-architectures)

## Architectural Principles

DocJet Mobile follows these key principles:

1. **Clean Architecture** - Clear separation of concerns between layers
2. **Domain-Driven Design** - Core business logic in a pure Dart domain layer
3. **Repository Pattern** - Abstraction over data sources with consistent interfaces
4. **Offline-First** - Local storage with remote synchronization
5. **Reactive UI** - State management for reactive user interfaces

## Layered Architecture

The application uses a Clean Architecture approach with 4 main layers:

```mermaid
%%{init: {'flowchart': {'defaultRenderer': 'elk'}}}%%
graph TD
    subgraph "Presentation Layer"
        UI[UI Components]
        StateManagement[State Management]
        UI <--> StateManagement
    end
    
    subgraph "Use Cases Layer"
        UseCases[Feature Use Cases]
    end
    
    subgraph "Domain Layer"
        Entities[Business Entities]
        Repositories[Repository Interfaces]
        Failures[Failure Objects]
    end
    
    subgraph "Data Layer"
        RepoImpl[Repository Implementations]
        Services[Specialized Services]
        RemoteDS[Remote Data Sources]
        LocalDS[Local Data Sources]
        DTOs[Data Transfer Objects]
    end
    
    subgraph "Core / Infrastructure"
        DI[Dependency Injection]
        Auth[Authentication]
        Platform[Platform Abstractions]
        Utils[Utilities]
    end
    
    StateManagement --> UseCases
    UseCases --> Repositories
    
    RepoImpl --> Repositories
    RepoImpl --> Services
    Services --> RemoteDS
    Services --> LocalDS
    RemoteDS --> DTOs
    LocalDS --> DTOs
    
    RepoImpl -.-> DI
    RemoteDS -.-> Auth
    LocalDS -.-> Platform
    
    classDef domain padding:15px;
    
    class UI,StateManagement presentation;
    class UseCases usecases;
    class Entities,Repositories,Failures domain;
    class RepoImpl,Services,RemoteDS,LocalDS,DTOs data;
    class DI,Auth,Platform,Utils core;
```

### Presentation Layer
- UI components (screens, widgets)
- State management (Cubits/BLoCs)
- Navigation

### Use Cases Layer
- Feature-specific use cases
- Business logic orchestration
- Single responsibility actions
- Includes standard `UseCase` for single actions and `StreamUseCase` for reactive data flows.
- Bridge between Presentation and Domain

### Domain Layer
- Business entities (pure Dart objects)
- Repository interfaces
- Failure handling

### Data Layer
- Repository implementations
- Specialized services (readers, writers, orchestrators)
- Remote data sources (API clients)
- Local data sources (database)
- Data transfer objects (DTOs)

### Core / Infrastructure
- Dependency injection
- Authentication
- Platform abstraction (file system, network)
- Shared utilities

## Job Feature Architecture

For the Jobs feature, we use a service-oriented repository pattern:

```mermaid badge="Updated Diagram"
%%{init: {'flowchart': {'defaultRenderer': 'elk'}}}%%
graph TD
    subgraph "Jobs Feature"
        subgraph "Presentation"
            JobsUI[Job List / Detail UI]
            JobListCubit[JobListCubit]
            JobDetailCubit[JobDetailCubit]
        end

        subgraph "Use Cases"
            GetJobs[GetJobsUseCase]
            GetJobById[GetJobByIdUseCase]
            CreateJob[CreateJobUseCase]
            UpdateJob[UpdateJobUseCase]
            DeleteJob[DeleteJobUseCase]
            ResetFailedJob[ResetFailedJobUseCase]
            WatchJobs[WatchJobsUseCase]
            WatchJobById[WatchJobByIdUseCase]
        end

        subgraph "Domain"
            JobEntity[Job Entity]
            SyncStatus[Sync Status]
            JobRepo[JobRepository Interface]
        end

        subgraph "Data"
            RepoImpl[JobRepositoryImpl]

            subgraph "Services"
                ReaderSvc[JobReaderService]
                WriterSvc[JobWriterService]
                DeleterSvc[JobDeleterService]
                SyncOrch[JobSyncOrchestratorService]
                SyncProc[JobSyncProcessorService]
                SyncTrigger[JobSyncTriggerService]
            end

            LocalDS[JobLocalDataSource]
            RemoteDS[JobRemoteDataSource]
        end

        %% UI to Cubit/Use Case Connections
        JobsUI <--> JobListCubit
        JobsUI <--> JobDetailCubit
        JobsUI --> CreateJob  // Direct actions might still go to Use Cases
        JobsUI --> UpdateJob
        JobsUI --> DeleteJob
        JobsUI --> ResetFailedJob

        %% Cubit to Use Case Connections (Reactive)
        JobListCubit --> WatchJobs
        JobDetailCubit --> WatchJobById

        %% Use Case to Repository Connections
        GetJobs --> JobRepo
        GetJobById --> JobRepo
        CreateJob --> JobRepo
        UpdateJob --> JobRepo
        DeleteJob --> JobRepo
        ResetFailedJob --> JobRepo
        WatchJobs --> JobRepo
        WatchJobById --> JobRepo

        %% Data Layer Connections
        RepoImpl --> JobRepo
        RepoImpl --> ReaderSvc
        RepoImpl --> WriterSvc
        RepoImpl --> DeleterSvc
        RepoImpl --> SyncOrch
        SyncTrigger --> SyncOrch
        SyncOrch --> SyncProc
        ReaderSvc --> LocalDS
        WriterSvc --> LocalDS
        DeleterSvc --> LocalDS
        SyncOrch --> LocalDS
        SyncProc --> LocalDS
        ReaderSvc --> RemoteDS
        SyncProc --> RemoteDS
    end

    %% Class Definitions
    class JobsUI,JobListCubit,JobDetailCubit presentation; // Updated presentation layer classes
    class GetJobs,GetJobById,CreateJob,UpdateJob,DeleteJob,ResetFailedJob,WatchJobs,WatchJobById usecases;
    class JobEntity,SyncStatus,JobRepo domain;
    class RepoImpl,LocalDS,RemoteDS data;
    class ReaderSvc,WriterSvc,DeleterSvc,SyncOrch,SyncProc,SyncTrigger services; // Corrected class name
```

## Feature Architectures

Detailed architecture documentation for specific features:

1. [Jobs Feature Architecture](./job_dataflow.md) - Components and data flow for jobs
2. [Jobs Feature: Presentation Layer](./job_presentation_layer.md) - State management and UI interaction
3. [Authentication Architecture](./auth_architecture.md) - Authentication components and flows

## Authentication

The application uses a domain-level authentication context approach, keeping user identity concerns properly isolated:

### Authentication Components
- **AuthCredentialsProvider**: Infrastructure-level provider managing secure storage and retrieval of authentication tokens and user identity
- **AuthSessionProvider**: Domain-level interface that provides authentication context to components without exposing implementation details
  - **Methods**: `isAuthenticated()` → `Future<bool>`, `getCurrentUserId()` → `Future<String>`
  - **Error Handling**: Throws `AuthException.unauthenticated()` when no user is authenticated
- **SecureStorageAuthSessionProvider**: Implementation connecting the domain-level interface to infrastructure
- **AuthService**: Higher-level service for user login, logout, and session management

### Authentication Context Flow
This architecture avoids passing user IDs through UI and domain layers:
- UI components don't need to track or pass user IDs
- Domain interfaces are simpler and focus on business operations
- Repository implementations retrieve user context directly from `AuthSessionProvider` 
- Authentication errors are handled consistently at the data layer

### Future Authentication Enhancements
The following enhancements identified in the [Authentication Architecture](./auth_architecture.md) document are planned:

1. **User Profile Retrieval**: Enhance the system to retrieve full user profile after authentication
2. **Local Token Validation**: Add JWT expiration validation without requiring API calls
3. **Improved Exception Handling**: Develop more specific authentication exception types
4. **Offline Authentication Support**: Implement graceful fallbacks when network is unavailable
5. **Robust Error Recovery**: Add exponential backoff for transient auth errors
6. **Auth Event System**: Create centralized event notification for auth state changes

The introduction of `AuthSessionProvider` lays groundwork for items 2 and 3, by providing a clean domain-level abstraction for authentication state and centralizing error handling through standard exceptions.
