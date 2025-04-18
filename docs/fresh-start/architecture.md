# DocJet Mobile Architecture

This document provides an overview of the DocJet Mobile application architecture.

## Table of Contents

1. [Architectural Principles](#architectural-principles)
2. [Layered Architecture](#layered-architecture)
3. [Feature Architectures](#feature-architectures)
4. [Documentation Guidelines](#documentation-guidelines)

## Architectural Principles

DocJet Mobile follows these key principles:

1. **Clean Architecture** - Clear separation of concerns between layers
2. **Domain-Driven Design** - Core business logic in a pure Dart domain layer
3. **Repository Pattern** - Abstraction over data sources with consistent interfaces
4. **Offline-First** - Local storage with remote synchronization
5. **Reactive UI** - State management for reactive user interfaces

## Layered Architecture

The application uses a 3-layer architecture:

```mermaid
%%{init: {'flowchart': {'defaultRenderer': 'elk'}}}%%
graph TD
    subgraph "Presentation Layer"
        UI[UI Components]
        StateManagement[State Management]
        UI <--> StateManagement
    end
    
    subgraph "Domain Layer"
        Entities[Business Entities]
        Repositories[Repository Interfaces]
        Services[Domain Services]
        Failures[Failure Objects]
    end
    
    subgraph "Data Layer"
        RepoImpl[Repository Implementations]
        RemoteDS[Remote Data Sources]
        LocalDS[Local Data Sources]
        DTOs[Data Transfer Objects]
    end
    
    StateManagement --> Repositories
    StateManagement --> Services
    
    RepoImpl --> Repositories
    RepoImpl --> RemoteDS
    RepoImpl --> LocalDS
    RemoteDS --> DTOs
    LocalDS --> DTOs
    
    classDef presentation fill:#0F9D58,stroke:#222,stroke-width:2px,color:#fff;
    classDef domain fill:#E64A45,stroke:#222,stroke-width:2px,color:#fff,padding:15px;
    classDef data fill:#4285F4,stroke:#222,stroke-width:2px,color:#fff;
    
    class UI,StateManagement presentation;
    class Entities,Repositories,Services,Failures domain;
    class RepoImpl,RemoteDS,LocalDS,DTOs data;
```

### Presentation Layer
- UI components (screens, widgets)
- State management (Cubits/BLoCs)
- Navigation

### Domain Layer
- Business entities (pure Dart objects)
- Repository interfaces
- Domain services
- Failure handling

### Data Layer
- Repository implementations
- Remote data sources (API clients)
- Local data sources (database)
- Data transfer objects (DTOs)

## Feature Architectures

Detailed architecture documentation for specific features:

1. [Jobs Feature Architecture](./job_dataflow.md) - Components and data flow for jobs
2. [Authentication Architecture](./auth_architecture.md) - Authentication components and flows

## Documentation Guidelines

For creating consistent documentation and diagrams:

1. [Mermaid Guidelines](./mermaid_guidelines.md) - Standards for creating Mermaid diagrams
