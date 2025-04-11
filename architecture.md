# Architecture: Audio Transcription Feature

This document outlines the **implemented architecture** for the audio recording and transcription feature, based on a **Feature-Sliced Clean Architecture** approach. Local audio files are treated as payloads for a backend transcription service, with local persistence (Hive) managing offline jobs and metadata like duration.

***Note (April 8th, 2024): This document has been updated to reflect the actual codebase structure and implementation status. The architecture uses feature-slicing, and core functionality (local storage, fake API interaction, repository logic, basic presentation) is largely implemented.***

## 1. Overall Structure (Feature-Sliced Clean Architecture)

The project utilizes a feature-sliced approach combined with Clean Architecture principles:

*   **`lib/core/`**: Contains application-wide, reusable components, abstractions, and utilities (DI, error handling, platform interfaces, base use cases, logging).
*   **`lib/features/`**: Houses individual, self-contained feature modules. Currently, only `audio_recorder` exists.
*   **`lib/features/<feature_name>/`**: Each feature internally follows Clean Architecture layers:
    *   **`domain/`**: Contains business logic, entities, repository interfaces, domain service interfaces, and feature-specific use cases. It has no dependencies on other layers.
    *   **`data/`**: Implements repository interfaces, defines data sources (local, remote), manages data models/DTOs, and data-specific exceptions/services. Depends only on `domain`.
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

## 3. Audio Playback Architecture (Refactored - April 2024)

The audio playback system was significantly refactored to improve testability and separation of concerns, moving away from a monolithic service. It now utilizes a **Clean Architecture approach with Adapter and Mapper patterns**.

This refactoring addressed challenges in testing complex asynchronous stream logic and tightly coupled dependencies. The new architecture isolates the third-party audio player (`audioplayers` package) and separates the logic for transforming raw player events into domain-specific state.

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
        ENTITY["PlaybackState (Freezed)"]
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
        PLAYER[audioplayers::AudioPlayer]
    end

    %% --- Dependencies --- 
    UI --> CUBIT
    CUBIT --> SVC_IF
    CUBIT --> ENTITY
    
    SVC_IMPL --> SVC_IF
    SVC_IMPL --> ADP_IF
    SVC_IMPL --> MAP_IF
    
    ADP_IMPL --> ADP_IF
    MAP_IMPL --> MAP_IF
    
    ADP_IMPL --> PLAYER
    MAP_IMPL --> ENTITY
    MAP_IMPL -- Uses --> PLAYER
    MAP_IMPL -- Uses --> ADP_IF

    %% Grouping for Layout Hint (Optional)
    subgraph Feature
      direction LR
      subgraph Presentation [Presentation Layer]
        UI
        CUBIT
      end
      subgraph Domain [Domain Layer]
        ENTITY
        SVC_IF
        ADP_IF
        MAP_IF
      end
      subgraph Data [Data Layer]
        SVC_IMPL
        ADP_IMPL
        MAP_IMPL
      end
    end
    
    Presentation --> Domain
    Data --> Domain
    Data --> External

```

### 3.2. Relevant File Structure

```
lib/features/audio_recorder/
├── domain/
│   ├── adapters/
│   │   └── audio_player_adapter.dart      # Interface: Abstracts audio player operations & events
│   ├── entities/
│   │   └── playback_state.dart          # Entity (Freezed): Defines possible playback states
│   ├── mappers/
│   │   └── playback_state_mapper.dart   # Interface: Abstracts raw event -> PlaybackState mapping
│   └── services/
│       └── audio_playback_service.dart  # Interface: Defines high-level playback control API
├── data/
│   ├── adapters/
│   │   └── audio_player_adapter_impl.dart # Implementation: Wraps 'audioplayers' package
│   ├── mappers/
│   │   └── playback_state_mapper_impl.dart# Implementation: Maps raw streams to PlaybackState using RxDart
│   └── services/
│       └── audio_playback_service_impl.dart # Implementation: Orchestrates Adapter & Mapper
└── presentation/
    ├── cubit/
    │   ├── audio_list_cubit.dart        # State Management: Handles UI logic, interacts with Service
    │   └── audio_list_state.dart        # State Definition: Includes PlaybackInfo for UI
    └── widgets/
        └── audio_player_widget.dart     # UI Component: Displays playback controls & info
```

### 3.3. File Responsibilities

*   **Domain Layer:**
    *   `domain/adapters/audio_player_adapter.dart`: Defines the *contract* for how the application interacts with *any* audio player. Specifies methods (play, pause, stop, seek, setSourceUrl, dispose) and output streams (`onPlayerStateChanged`, `onDurationChanged`, `onPositionChanged`, `onPlayerComplete`). It isolates the rest of the app from the specifics of the `audioplayers` package.
    *   `domain/entities/playback_state.dart`: Defines the core *business state* of playback using a `freezed` sealed class (`initial`, `loading`, `playing`, `paused`, `stopped`, `completed`, `error`). This is the canonical representation of state used within the domain and presentation layers.
    *   `domain/mappers/playback_state_mapper.dart`: Defines the *contract* for transforming the raw, low-level event streams provided by the `AudioPlayerAdapter` into the unified, high-level `Stream<PlaybackState>`. It includes an `initialize` method signature to signal the need for input streams and a `dispose` method.
    *   `domain/services/audio_playback_service.dart`: Defines the high-level *use cases* for audio playback available to the presentation layer (play, pause, resume, seek, stop, dispose). It exposes the final `Stream<PlaybackState>` for UI updates.
*   **Data Layer:**
    *   `data/adapters/audio_player_adapter_impl.dart`: *Implements* the `AudioPlayerAdapter` interface using the `audioplayers` package. It holds an instance of `AudioPlayer`, delegates method calls directly to it, and exposes its raw streams. **Crucially, its `setSourceUrl` implementation now correctly uses `Uri.tryParse` to detect the scheme and calls `_audioPlayer.setSource` with either `DeviceFileSource` for local paths or `UrlSource` for network URLs.**
    *   `data/mappers/playback_state_mapper_impl.dart`: *Implements* the `PlaybackStateMapper`. It takes the raw streams from the adapter (via its `initialize` method), uses `rxdart`