# Architecture: Audio Transcription Feature

This document outlines the **implemented architecture** for the audio recording and transcription feature, based on a **Feature-Sliced Clean Architecture** approach. Local audio files are treated as payloads for a backend transcription service, with local persistence (Hive) managing offline jobs and metadata like duration.

***Note (April 8th, 2024): This document has been updated to reflect the actual codebase structure and implementation status. The architecture uses feature-slicing, and core functionality (local storage, fake API interaction, repository logic, basic presentation) is largely implemented.***

## 1. Overall Structure (Feature-Sliced Clean Architecture)

The project utilizes a feature-sliced approach combined with Clean Architecture principles:

*   **`lib/core/`**: Contains application-wide, reusable components, abstractions, and utilities (DI, error handling, platform interfaces, base use cases, logging).
*   **`lib/features/`**: Houses individual, self-contained feature modules. Currently, only `audio_recorder` exists.
*   **`lib/features/<feature_name>/`**: Each feature internally follows Clean Architecture layers:
    *   **`domain/`**: Contains business logic, entities, models, repository interfaces, domain service interfaces, adapters, mappers, and feature-specific use cases. It has no dependencies on other layers.
    *   **`data/`**: Implements repository interfaces, defines data sources (local, remote), manages data models/DTOs, data-specific exceptions, factories, services, adapters, and mappers. Depends only on `domain`.
    *   **`presentation/`**: Contains UI elements (pages, widgets) and state management (Cubits/Blocs). Depends only on `domain`.

```mermaid
graph LR
    subgraph Core [lib/core]
        direction TB
        CORE_DI[DI: get_it]
        CORE_ERROR[Error: Failures]
        CORE_PLATFORM[Platform Interfaces]
        CORE_UTILS[Utils: Logger]
        CORE_USECASE[Base Usecase]
    end

    subgraph Feature_audio_recorder [Feature: audio_recorder]
        direction TB
        F_PRES[Presentation Layer]
        F_DOM[Domain Layer]
        F_DATA[Data Layer]

        subgraph F_PRES [Presentation Layer]
            direction LR
            PRES_PAGE[Pages]
            PRES_CUBIT[Cubits]
            PRES_WIDGET[Widgets]
        end

        subgraph F_DOM [Domain Layer]
            direction LR
            DOM_ENTITY[Entities]
            DOM_REPO[Repository Interfaces]
            DOM_SVC[Service Interfaces]
            DOM_USECASE[Use Cases]
        end

        subgraph F_DATA [Data Layer]
            direction LR
            DATA_REPO[Repository Impls]
            DATA_DS[Data Sources]
            DATA_SVC[Service Impls]
            DATA_EXC[Exceptions]
        end

        %% Internal Feature Dependencies
        F_PRES --> F_DOM
        F_DATA --> F_DOM
        PRES_CUBIT --> PRES_PAGE
        PRES_WIDGET --> PRES_PAGE
        DATA_DS --> DATA_REPO
        DATA_SVC --> DATA_REPO
        DATA_SVC --> DATA_DS
        PRES_CUBIT --> DOM_ENTITY
        F_PRES --> DOM_REPO

    end

    subgraph External [External Dependencies]
      direction TB
      ExternalSDK[Platform SDK]
      ExternalDB[(Hive DB)]
      ExternalAPI((Backend API))
      ExternalMic[record package]
      ExternalAudio[just_audio]
    end

    %% Core to Feature/External Dependencies
    Core --> Feature_audio_recorder
    CORE_DI --> F_PRES
    CORE_DI --> F_DATA
    CORE_ERROR --> F_DOM
    CORE_ERROR --> F_DATA
    CORE_PLATFORM --> DATA_DS
    CORE_PLATFORM --> DATA_SVC
    CORE_PLATFORM --> ExternalSDK

    %% Feature/Data to External Dependencies
    Feature_audio_recorder --> External
    DATA_DS --> ExternalDB
    DATA_DS --> ExternalAPI
    DATA_DS --> ExternalMic
    DATA_SVC --> ExternalAudio

    %% Styling
    style Core fill:#eee,stroke:#333,stroke-width:1px
    style Feature_audio_recorder fill:#eef,stroke:#333,stroke-width:1px
    style External fill:#efe,stroke:#333,stroke-width:1px

```

*(Note: This diagram shows the general structure and dependencies for the `audio_recorder` feature within the overall architecture.)*

## 2. Implemented Architecture Details

This architecture treats local files as opaque handles/payloads. The primary source of truth for list display is a **merged state** derived from the backend API (via `TranscriptionRemoteDataSource`) and local persistence (`LocalJobStore` using Hive). **Local audio duration is captured ONCE after recording and stored locally via `LocalJobStore`.**

**Key Components & Flow (Listing):**

1.  **Local Job Capture & Persistence (Implemented):**
    *   `AudioDurationRetriever` (`data/services/`) is called by `AudioLocalDataSourceImpl.stopRecording()` (`data/datasources/`).
    *   `AudioLocalDataSourceImpl` creates a `LocalJob` entity (`domain/entities/`) with `status = created`, `durationMillis`, `localFilePath`, `localCreatedAt`.
    *   It saves this `LocalJob` using the injected `LocalJobStore` interface (`domain/repositories/`).
    *   **`LocalJobStore` Interface (Domain - Implemented):** Defines the contract for local persistence.
    *   **Implementation (`HiveLocalJobStoreImpl` - Implemented):** Uses `Hive` (`data/datasources/`) to store `LocalJob` objects. Hive is initialized, adapters registered, and the store injected via `get_it` (`core/di/`).
2.  **Simplified Local File Listing (Assumed via `AudioFileManager`):**
    *   `AudioFileManager` (`data/services/`) likely provides basic path listing, removing the old N+1 problem (implementation details not fully verified but structure exists).
3.  **Backend Integration (Interface + Fake Implementation):**
    *   **`TranscriptionRemoteDataSource` Interface (Domain - Implemented):** Defines contract (`

## 3. Audio Playback Architecture (Refactored & Standardized - DATE)

**UPDATE (DATE - Please fill in):** The audio playback system has been **standardized on `just_audio`**. Phase 1 (Interface Decoupling) and Phase 2 (Standardize on `just_audio`) are complete. The `AudioPlayerAdapterImpl` now uses `just_audio` exclusively, and the `audioplayers` dependency has been removed.

**REVISED PLAN (Completed):**
1.  **Phase 1 (Interface Decoupling - COMPLETE):** Defined `DomainPlayerState` enum. Updated `AudioPlayerAdapter` interface to use `DomainPlayerState`. Updated the `audioplayers`-based `AudioPlayerAdapterImpl` and the `PlaybackStateMapper` implementation & tests to conform to the new interface contract.
2.  **Phase 2 (Standardize on `just_audio` - COMPLETE):** Rewrote the `AudioPlayerAdapterImpl` to use `just_audio` instead of `audioplayers`. Updated the adapter tests accordingly. Removed the `audioplayers` dependency entirely.

The following description reflects the current state *after* standardization on `just_audio`.

The audio playback system utilizes a Clean Architecture approach with Adapter and Mapper patterns, standardized on `just_audio` for all playback and duration-related operations.

### 3.1. Playback Architecture Diagram

```mermaid
graph LR
    subgraph "Presentation Layer (UI & State)"
        direction LR
        UI[AudioPlayerWidget]
        CUBIT[AudioListCubit]
    end

    subgraph "Domain Layer (Interf & Ent)"
        direction LR
        ENTITY_PSTATE["PlaybackState (Freezed)"]
        ENTITY_DSTATE["DomainPlayerState (enum)"]
        SVC_IF[AudioPlaybackService Interface]
        ADP_IF[AudioPlayerAdapter Interface]
        MAP_IF[PlaybackStateMapper Interface]
    end

    subgraph "Data Layer (Implementations)"
        direction LR
        SVC_IMPL[AudioPlaybackServiceImpl]
        ADP_IMPL[AudioPlayerAdapterImpl]
        MAP_IMPL[PlaybackStateMapperImpl]
    end

    subgraph "External Dependencies"
        direction LR
        PLAYER[just_audio::AudioPlayer]
        // PLAYER_DURATION[just_audio::AudioPlayer] // No longer needed as separate item
    end

    %% --- Dependencies --- 
    UI --> CUBIT
    CUBIT --> SVC_IF
    CUBIT --> ENTITY_PSTATE
    
    SVC_IMPL --> SVC_IF
    SVC_IMPL --> ADP_IF
    SVC_IMPL --> MAP_IF
    
    ADP_IMPL --> ADP_IF
    MAP_IMPL --> MAP_IF
    
    ADP_IMPL --> PLAYER
    MAP_IMPL --> ENTITY_PSTATE
    MAP_IMPL -- Uses --> ENTITY_DSTATE
    MAP_IMPL -- Consumes Stream From --> ADP_IF
    // SVC_DURATION[AudioDurationRetrieverImpl] -- Uses --> PLAYER_DURATION // Duration handled by adapter?

    %% Interface/Entity usage
    ADP_IF -- Emits --> ENTITY_DSTATE
    MAP_IF -- Consumes --> ENTITY_DSTATE
    MAP_IF -- Emits --> ENTITY_PSTATE
    SVC_IF -- Emits --> ENTITY_PSTATE

    %% Grouping for Layout Hint (Optional)
    subgraph Feature
      direction LR
      subgraph Presentation [Presentation Layer]
        UI
        CUBIT
      end
      subgraph Domain [Domain Layer]
        ENTITY_PSTATE
        ENTITY_DSTATE
        SVC_IF
        ADP_IF
        MAP_IF
      end
      subgraph Data [Data Layer]
        SVC_IMPL
        ADP_IMPL
        MAP_IMPL
        // SVC_DURATION // Removed? Or handled differently?
      end
    end
    
    Presentation --> Domain
    Data --> Domain
    Data --> External

```
(Note: Diagram updated to reflect single `just_audio` dependency)

### 3.2. Relevant File Structure

```
lib/features/audio_recorder/
├── domain/
│   ├── adapters/
│   │   └── audio_player_adapter.dart      # Interface: Abstracts player. Uses DomainPlayerState.
│   ├── entities/
│   │   ├── domain_player_state.dart     # Entity (enum): Library-agnostic player states.
│   │   └── playback_state.dart          # Entity (Freezed): UI-facing playback states.
│   ├── mappers/
│   │   └── playback_state_mapper.dart   # Interface: Abstracts raw event -> PlaybackState.
│   ├── models/                          # Domain specific models (if any, separate from entities)
│   ├── repositories/                    # Repository Interfaces (e.g., LocalJobStore)
│   ├── services/
│   │   └── audio_playback_service.dart  # Interface: High-level playback API.
│   └── usecases/                        # Feature specific business logic units
├── data/
│   ├── adapters/
│   │   └── audio_player_adapter_impl.dart # Implementation: Wraps 'just_audio'. Maps to DomainPlayerState.
│   ├── datasources/                     # Data source implementations (e.g., HiveLocalJobStoreImpl)
│   ├── exceptions/                      # Data layer specific exceptions
│   ├── factories/                       # Factories for creating data layer objects
│   ├── mappers/
│   │   └── playback_state_mapper_impl.dart# Implementation: Maps DomainPlayerState -> PlaybackState.
│   ├── repositories/                    # Repository Implementations
│   └── services/
│       ├── audio_duration_retriever_impl.dart # IMPL: Uses 'just_audio' for duration. (Still separate?)
│       └── audio_playback_service_impl.dart # Implementation: Orchestrates Adapter & Mapper.
└── presentation/
    ├── cubit/
    │   ├── audio_list_cubit.dart        # State Management: Uses AudioPlaybackService.
    │   └── audio_list_state.dart        # State Definition: Includes PlaybackInfo.
    ├── pages/                           # Feature screens/pages
    └── widgets/
        └── audio_player_widget.dart     # UI Component: Displays controls & info.
```

### 3.3. File Responsibilities (Updated)

*   **Domain Layer:**
    *   `domain/adapters/audio_player_adapter.dart`: Defines the *contract* for interacting with *any* audio player. Uses `DomainPlayerState`.
    *   `domain/entities/domain_player_state.dart`: Defines the library-agnostic player states.
    *   `domain/entities/playback_state.dart`: Defines the core *business state* (`initial`, `loading`, `playing`, etc.).
    *   `domain/mappers/playback_state_mapper.dart`: Defines the *contract* for transforming event streams into `Stream<PlaybackState>`. Consumes `Stream<DomainPlayerState>`.
    *   `domain/services/audio_playback_service.dart`: Defines the high-level playback use cases. Exposes `Stream<PlaybackState>`.
*   **Data Layer:**
    *   `data/adapters/audio_player_adapter_impl.dart`: *Implements* `AudioPlayerAdapter` using **`just_audio`**. Maps internal `just_audio` states to `DomainPlayerState`.
    *   `data/mappers/playback_state_mapper_impl.dart`: *Implements* `PlaybackStateMapper`. **Crucially, this implementation uses RxDart (`Rx.merge`, `BehaviorSubject`, etc.) to combine the various input streams (`positionStream`, `durationStream`, `playerStateStream`, `completeStream`) provided by the `AudioPlayerAdapter` via the `initialize` method. It maintains internal state (`_currentPlayerState`, `_currentDuration`, `_currentPosition`) and constructs the final `PlaybackState` based on the latest events from all input streams. It exposes the resulting combined and mapped `Stream<PlaybackState>`.**
    *   `data/services/audio_duration_retriever_impl.dart`: (**NOTE:** Still uses `just_audio`. Could potentially be merged or simplified now that the main player uses `just_audio`, but kept separate for now.)
    *   `data/services/audio_playback_service_impl.dart`: Orchestrates the playback lifecycle by calling methods on the `AudioPlayerAdapter` (e.g., `play`, `pause`, `stop`, `setSourceUrl`). **It initializes the `PlaybackStateMapper` by passing the necessary streams from the adapter. It then simply exposes the `playbackStateStream` provided by the mapper, acting as a pass-through for the combined state rather than performing the stream combination itself.**
