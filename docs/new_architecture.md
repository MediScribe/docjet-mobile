# Transcription Audio Player: Complete Architecture

This document provides a comprehensive view of the entire Transcription Audio Player architecture, showing all components and their relationships.

## System Overview

```mermaid
graph TB
    %% Main layers of the application
    subgraph Presentation [Presentation Layer]
        direction TB
        Screen[TranscriptionListScreen]
        ListView[TranscriptionListView]
        ItemWidget[TranscriptionItemWidget]
        PlayerWidget[AudioPlayerControlWidget]
    end
    
    subgraph StateManagement [State Management Layer]
        direction TB
        Cubit[TranscriptionCubit]
        State[TranscriptionState<br>UI Model]
    end
    
    subgraph Domain [Domain Layer]
        direction TB
        Entities[Domain Entities<br>Transcription<br>TranscriptionList]
        Services[Domain Services<br>AudioPlayerService<br>TranscriptionService]
    end
    
    subgraph Data [Data Access Layer]
        direction TB
        Repository[TranscriptionRepository]
        LocalDataSource[LocalStorage]
        RemoteDataSource[ApiClient]
        FileSystem[FileSystem]
    end
    
    subgraph External [External Dependencies]
        direction TB
        JustAudio[just_audio]
        Hive[Hive Database]
        BackendAPI[Backend API]
        NativeFS[Native File System]
    end
    
    %% Connections between components
    Screen --> ListView
    ListView --> ItemWidget
    ItemWidget --> PlayerWidget
    
    Screen -- Provides --> Cubit
    ListView -- Consumes --> State
    ItemWidget -- Consumes --> State
    PlayerWidget -- Consumes --> State
    
    ItemWidget -- User Actions --> Cubit
    PlayerWidget -- User Actions --> Cubit
    
    Cubit -- "emit(state)" --> State
    Cubit -- Uses --> Services
    Cubit -- Calls --> Repository
    
    Repository -- Creates --> Entities
    Repository -- Uses --> LocalDataSource
    Repository -- Uses --> RemoteDataSource
    Repository -- Uses --> FileSystem
    
    Services -- Uses --> JustAudio
    LocalDataSource -- Uses --> Hive
    RemoteDataSource -- Uses --> BackendAPI
    FileSystem -- Uses --> NativeFS
    
    %% Styling
    classDef presentation fill:#dae8fc,stroke:#6c8ebf,stroke-width:1px
    classDef stateManagement fill:#d5e8d4,stroke:#82b366,stroke-width:1px
    classDef domain fill:#fff2cc,stroke:#d6b656,stroke-width:1px
    classDef data fill:#f8cecc,stroke:#b85450,stroke-width:1px
    classDef external fill:#e1d5e7,stroke:#9673a6,stroke-width:1px
    
    class Screen,ListView,ItemWidget,PlayerWidget presentation
    class Cubit,State stateManagement
    class Entities,Services domain
    class Repository,LocalDataSource,RemoteDataSource,FileSystem data
    class JustAudio,Hive,BackendAPI,NativeFS external
```

## Detailed Component Breakdown

### Domain Layer (Business Logic)

```mermaid
classDiagram
    class Transcription {
        +String id
        +String text
        +String audioFilePath
        +Duration duration
        +DateTime createdAt
        +fromJson(json) Transcription
    }
    
    class TranscriptionList {
        +List~Transcription~ items
        +findById(String id) Transcription?
        +sortByDate() List~Transcription~
    }
    
    class AudioPlayerService {
        +play(String filePath) Future~void~
        +pause() Future~void~
        +seekTo(Duration position) Future~void~
        +stop() Future~void~
        +getDuration(String filePath) Future~Duration~
        +Stream~AudioState~ get stateStream
    }
    
    class TranscriptionService {
        +processTranscription(String audioPath) Future~void~
        +updateTranscription(Transcription transcription) Future~void~
    }
    
    TranscriptionList o-- Transcription : contains
```

### Data Access Layer (Data Sources)

```mermaid
classDiagram
    class TranscriptionRepository {
        -ApiClient _apiClient
        -LocalStorage _localStorage
        -FileSystem _fileSystem
        +getTranscriptions() Future~TranscriptionList~
        +getTranscriptionById(String id) Future~Transcription~
        +getAudioFilePath(String id) Future~String~
        +saveTranscription(Transcription) Future~void~
    }
    
    class ApiClient {
        +fetchTranscriptions() Future~List~json~~
        +fetchTranscriptionById(String id) Future~json~
        +uploadAudio(String filePath) Future~String~
    }
    
    class LocalStorage {
        +getTranscriptions() Future~List~Transcription~~
        +saveTranscriptions(List~Transcription~) Future~void~
        +getTranscriptionById(String id) Future~Transcription~
    }
    
    class FileSystem {
        +readFile(String path) Future~Uint8List~
        +writeFile(String path, Uint8List data) Future~void~
        +fileExists(String path) Future~bool~
        +deleteFile(String path) Future~void~
    }
    
    TranscriptionRepository -- ApiClient : uses
    TranscriptionRepository -- LocalStorage : uses
    TranscriptionRepository -- FileSystem : uses
```

### State Management Layer

```mermaid
classDiagram
    class TranscriptionState {
        +TranscriptionList? transcriptionList
        +bool isLoading
        +String? error
        +String? selectedId
        +String? playingId
        +bool isPlaying
        +Duration position
        +Duration? duration
        +Transcription? get selectedTranscription
        +copyWith(...) TranscriptionState
    }
    
    class TranscriptionCubit {
        -TranscriptionRepository _repository
        -AudioPlayerService _audioService
        +loadTranscriptions() Future~void~
        +selectTranscription(String id) void
        +playTranscription(String id) Future~void~
        +pausePlayback() Future~void~
        +seekTo(Duration position) Future~void~
        +stopPlayback() Future~void~
    }
    
    TranscriptionCubit -- TranscriptionState : emits
```

### Presentation Layer (UI)

```mermaid
classDiagram
    class TranscriptionListScreen {
        +build(BuildContext) Widget
    }
    
    class TranscriptionListView {
        -List~Transcription~ transcriptions
        -String? selectedId
        -Function(String) onSelectItem
        +build(BuildContext) Widget
    }
    
    class TranscriptionItemWidget {
        -Transcription transcription
        -bool isSelected
        -bool isPlaying
        -Function() onTap
        +build(BuildContext) Widget
    }
    
    class AudioPlayerControlWidget {
        -bool isPlaying
        -Duration position
        -Duration duration
        -Function() onPlay
        -Function() onPause
        -Function(Duration) onSeek
        +build(BuildContext) Widget
    }
    
    TranscriptionListScreen o-- TranscriptionListView : contains
    TranscriptionListView o-- TranscriptionItemWidget : contains
    TranscriptionItemWidget o-- AudioPlayerControlWidget : contains when selected
```

## Data Flow Diagrams

### Application Startup

```mermaid
sequenceDiagram
    participant Screen as TranscriptionListScreen
    participant Cubit as TranscriptionCubit
    participant Repo as Repository
    participant API as ApiClient
    participant DB as LocalStorage
    
    Screen->>Cubit: created (DI injection)
    Cubit->>Cubit: emit initial state
    Screen->>Cubit: loadTranscriptions()
    Cubit->>Cubit: emit loading state
    Cubit->>Repo: getTranscriptions()
    
    alt Online
        Repo->>API: fetchTranscriptions()
        API-->>Repo: JSON data
        Repo->>Repo: create domain objects
        Repo->>DB: saveTranscriptions(domain objects)
    else Offline or API error
        Repo->>DB: getTranscriptions()
        DB-->>Repo: cached domain objects
    end
    
    Repo-->>Cubit: TranscriptionList
    Cubit->>Cubit: emit loaded state with transcriptions
    Cubit-->>Screen: state updated
    Screen->>Screen: rebuild UI with data
```

### Audio Playback

```mermaid
sequenceDiagram
    participant User as User
    participant Item as TranscriptionItemWidget
    participant Player as AudioPlayerControlWidget
    participant Cubit as TranscriptionCubit
    participant Service as AudioPlayerService
    participant JustAudio as just_audio
    
    %% Select transcription
    User->>Item: tap item
    Item->>Cubit: selectTranscription(id)
    Cubit->>Cubit: emit state with selectedId
    
    %% Play audio
    User->>Player: tap play button
    Player->>Cubit: playTranscription()
    Cubit->>Repo: getAudioFilePath(selectedId)
    Repo-->>Cubit: filePath
    Cubit->>Service: play(filePath)
    Service->>JustAudio: setFilePath(filePath)
    Service->>JustAudio: play()
    
    %% Playback updates
    JustAudio-->>Service: position updates
    Service-->>Cubit: state stream updates
    Cubit->>Cubit: emit state with updated position
    Cubit-->>Player: rebuild with new position
    
    %% Seek interaction
    User->>Player: drag seek bar
    Player->>Player: update local position
    User->>Player: release seek bar
    Player->>Cubit: seekTo(position)
    Cubit->>Service: seekTo(position)
    Service->>JustAudio: seek(position)
```

## Dependency Injection

```mermaid
graph TB
    subgraph DI [Dependency Injection Container]
        direction TB
        JA[just_audio.AudioPlayer]
        FS[FileSystem]
        API[ApiClient]
        DB[LocalStorage]
        APS[AudioPlayerService]
        Repo[TranscriptionRepository]
        Cubit[TranscriptionCubit]
    end
    
    subgraph UI [UI Components]
        Screen[TranscriptionListScreen]
    end
    
    JA --> APS
    FS --> Repo
    API --> Repo
    DB --> Repo
    
    APS --> Cubit
    Repo --> Cubit
    
    Cubit --> Screen
    
    %% Registration
    DI -- "register singleton" --> JA
    DI -- "register singleton" --> FS
    DI -- "register singleton" --> API
    DI -- "register singleton" --> DB
    DI -- "register singleton" --> APS
    DI -- "register singleton" --> Repo
    DI -- "register singleton/factory" --> Cubit
    
    %% Styling
    classDef di fill:#d5e8d4,stroke:#82b366,stroke-width:1px
    classDef ui fill:#dae8fc,stroke:#6c8ebf,stroke-width:1px
    
    class DI,JA,FS,API,DB,APS,Repo,Cubit di
    class UI,Screen ui
```

## Key Insights

1. **Clean Separation of Concerns**:
   - Domain layer contains pure business logic and entities
   - Data layer handles data access and persistence
   - State management layer bridges domain and UI
   - Presentation layer focuses only on displaying state

2. **Unidirectional Data Flow**:
   - User actions flow down to the Cubit
   - Cubit updates state based on those actions
   - State changes flow back up to the UI
   - UI rebuilds based on new state

3. **Domain-Driven Design**:
   - Repository creates and returns domain objects
   - Business logic operates on domain objects
   - UI displays domain objects but doesn't modify them

4. **Single Source of Truth**:
   - TranscriptionState contains all data needed by the UI
   - No duplicated state across components
   - All state updates go through the Cubit

5. **Testability**:
   - Each component has a single responsibility
   - Dependencies are injected and can be mocked
   - Cubits expose predictable, testable methods
   - UI components are pure functions of their inputs

This architecture provides a scalable foundation for the Transcription Audio Player, with clear boundaries between components and a predictable data flow.

## Implementation Strategy

1. **Start with Domain Entities**:
   - Define Transcription and TranscriptionList classes
   - Implement basic domain logic

2. **Implement Data Access**:
   - Create API client and local storage
   - Implement repository and data sources

3. **Build State Management**:
   - Define TranscriptionState class
   - Implement TranscriptionCubit with core methods

4. **Create UI Components**:
   - Build TranscriptionListView and item widgets
   - Implement audio player controls
   - Connect widgets to Cubit

5. **Wire Everything Together**:
   - Set up dependency injection
   - Register all services and repositories
   - Connect UI to state management 