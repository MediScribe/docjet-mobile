# Transcription Audio Player: Revised Architecture

This document provides a comprehensive view of the Transcription Audio Player architecture, showing all components and their relationships with proper separation of concerns.

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
        RecordWidget[AudioRecordingWidget]
    end
    
    subgraph StateManagement [State Management Layer]
        direction TB
        ListCubit[TranscriptionCubit]
        RecordCubit[RecordingCubit]
        ListState[TranscriptionState]
        RecordState[RecordingState]
    end
    
    subgraph Domain [Domain Layer]
        direction TB
        Entities[Domain Entities<br>Transcription<br>TranscriptionList]
        Interfaces[Domain Interfaces<br>AudioPlayer<br>AudioRecorder<br>TranscriptionRepository]
        Services[Domain Services<br>TranscriptionService]
    end
    
    subgraph Data [Data Access Layer]
        direction TB
        RepositoryImpl[TranscriptionRepositoryImpl]
        AudioPlayerImpl[AudioPlayerImpl]
        AudioRecorderImpl[AudioRecorderImpl]
        LocalDataSource[LocalStorage]
        RemoteDataSource[ApiClient]
        FileSystem[FileSystem]
    end
    
    subgraph External [External Dependencies]
        direction TB
        JustAudio[just_audio]
        RecorderLib[flutter_sound/record]
        Hive[Hive Database]
        BackendAPI[Backend API]
        NativeFS[Native File System]
    end
    
    %% Connections between components
    Screen --> ListView
    ListView --> ItemWidget
    ItemWidget --> PlayerWidget
    Screen --> RecordWidget
    
    Screen -- Provides --> ListCubit
    Screen -- Provides --> RecordCubit
    ListView -- Consumes --> ListState
    ItemWidget -- Consumes --> ListState
    PlayerWidget -- Consumes --> ListState
    RecordWidget -- Consumes --> RecordState
    
    ItemWidget -- User Actions --> ListCubit
    PlayerWidget -- User Actions --> ListCubit
    RecordWidget -- User Actions --> RecordCubit
    
    ListCubit -- "emit(state)" --> ListState
    RecordCubit -- "emit(state)" --> RecordState
    ListCubit -- Uses --> Interfaces
    RecordCubit -- Uses --> Interfaces
    
    RepositoryImpl -- Implements --> Interfaces
    AudioPlayerImpl -- Implements --> Interfaces
    AudioRecorderImpl -- Implements --> Interfaces
    
    RepositoryImpl -- Creates --> Entities
    RepositoryImpl -- Uses --> LocalDataSource
    RepositoryImpl -- Uses --> RemoteDataSource
    RepositoryImpl -- Uses --> FileSystem
    
    AudioPlayerImpl -- Uses --> JustAudio
    AudioRecorderImpl -- Uses --> RecorderLib
    LocalDataSource -- Uses --> Hive
    RemoteDataSource -- Uses --> BackendAPI
    FileSystem -- Uses --> NativeFS
    
    %% Styling
    classDef presentation fill:#dae8fc,stroke:#6c8ebf,stroke-width:1px
    classDef stateManagement fill:#d5e8d4,stroke:#82b366,stroke-width:1px
    classDef domain fill:#fff2cc,stroke:#d6b656,stroke-width:1px
    classDef data fill:#f8cecc,stroke:#b85450,stroke-width:1px
    classDef external fill:#e1d5e7,stroke:#9673a6,stroke-width:1px
    
    class Screen,ListView,ItemWidget,PlayerWidget,RecordWidget presentation
    class ListCubit,RecordCubit,ListState,RecordState stateManagement
    class Entities,Interfaces,Services domain
    class RepositoryImpl,AudioPlayerImpl,AudioRecorderImpl,LocalDataSource,RemoteDataSource,FileSystem data
    class JustAudio,RecorderLib,Hive,BackendAPI,NativeFS external
```

## Detailed Component Breakdown

### Domain Layer (Pure Business Logic)

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
    
    class AudioPlayer {
        <<interface>>
        +play(String filePath) Future~void~
        +pause() Future~void~
        +seekTo(Duration position) Future~void~
        +stop() Future~void~
        +getDuration(String filePath) Future~Duration~
        +Stream~PlaybackState~ get stateStream
    }
    
    class AudioRecorder {
        <<interface>>
        +startRecording(String filePath) Future~void~
        +pauseRecording() Future~void~
        +resumeRecording() Future~void~
        +stopRecording() Future~String~
        +Stream~RecordingState~ get stateStream
        +Stream~double~ get levelStream
    }
    
    class TranscriptionRepository {
        <<interface>>
        +getTranscriptions() Future~TranscriptionList~
        +getTranscriptionById(String id) Future~Transcription~
        +getAudioFilePath(String id) Future~String~
        +saveTranscription(Transcription) Future~void~
        +createLocalTranscription(String audioPath) Future~Transcription~
        +uploadForTranscription(String id) Future~void~
    }
    
    class TranscriptionService {
        +processTranscription(String audioPath) Future~void~
        +updateTranscription(Transcription transcription) Future~void~
    }
    
    class PlaybackState {
        <<enum>>
        INITIAL
        LOADING
        PLAYING
        PAUSED
        STOPPED
        COMPLETED
        ERROR
    }
    
    class RecordingState {
        <<enum>>
        INITIAL
        RECORDING
        PAUSED
        STOPPED
        ERROR
    }
    
    TranscriptionList o-- Transcription : contains
    AudioPlayer -- PlaybackState : produces
    AudioRecorder -- RecordingState : produces
```

### Data Access Layer (Infrastructure Implementations)

```mermaid
classDiagram
    class TranscriptionRepositoryImpl {
        -ApiClient _apiClient
        -LocalStorage _localStorage
        -FileSystem _fileSystem
        +getTranscriptions() Future~TranscriptionList~
        +getTranscriptionById(String id) Future~Transcription~
        +getAudioFilePath(String id) Future~String~
        +saveTranscription(Transcription) Future~void~
        +createLocalTranscription(String audioPath) Future~Transcription~
        +uploadForTranscription(String id) Future~void~
    }
    
    class AudioPlayerImpl {
        -AudioPlayer _player
        +play(String filePath) Future~void~
        +pause() Future~void~
        +seekTo(Duration position) Future~void~
        +stop() Future~void~
        +getDuration(String filePath) Future~Duration~
        +Stream~PlaybackState~ get stateStream
        -_mapPlayerStateToPlaybackState(PlayerState) PlaybackState
    }
    
    class AudioRecorderImpl {
        -FlutterSoundRecorder _recorder
        +startRecording(String filePath) Future~void~
        +pauseRecording() Future~void~
        +resumeRecording() Future~void~
        +stopRecording() Future~String~
        +Stream~RecordingState~ get stateStream
        +Stream~double~ get levelStream
        -_mapRecorderStateToRecordingState(RecorderState) RecordingState
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
        +generateFilePath(String extension) String
    }
    
    class JustAudioLib {
        <<external>>
    }
    
    class RecorderLib {
        <<external>>
    }
    
    TranscriptionRepositoryImpl -- ApiClient : uses
    TranscriptionRepositoryImpl -- LocalStorage : uses
    TranscriptionRepositoryImpl -- FileSystem : uses
    AudioPlayerImpl -- JustAudioLib : adapts
    AudioRecorderImpl -- RecorderLib : adapts
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
        +PlaybackState playerState
        +Duration position
        +Duration? duration
        +Transcription? get selectedTranscription
        +copyWith(...) TranscriptionState
    }
    
    class TranscriptionCubit {
        -TranscriptionRepository _repository
        -AudioPlayer _audioPlayer
        +loadTranscriptions() Future~void~
        +selectTranscription(String id) void
        +playTranscription(String id) Future~void~
        +pausePlayback() Future~void~
        +seekTo(Duration position) Future~void~
        +stopPlayback() Future~void~
        +uploadForTranscription(String id) Future~void~
    }
    
    class RecordingState {
        +RecordingState recordingState
        +String? filePath
        +double audioLevel
        +Duration recordingDuration
        +String? error
        +copyWith(...) RecordingState
    }
    
    class RecordingCubit {
        -AudioRecorder _audioRecorder
        -TranscriptionRepository _repository
        -FileSystem _fileSystem
        +startRecording() Future~void~
        +pauseRecording() Future~void~
        +resumeRecording() Future~void~
        +stopRecording() Future~void~
        +cancelRecording() Future~void~
        +saveRecording() Future~void~
    }
    
    TranscriptionCubit -- TranscriptionState : emits
    RecordingCubit -- RecordingState : emits
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
        -PlaybackState playerState
        -Duration position
        -Duration duration
        -Function() onPlay
        -Function() onPause
        -Function(Duration) onSeek
        +build(BuildContext) Widget
    }
    
    class AudioRecordingWidget {
        -RecordingState recordingState
        -double audioLevel
        -Duration recordingDuration
        -Function() onStartRecording
        -Function() onPauseRecording
        -Function() onResumeRecording
        -Function() onStopRecording
        -Function() onCancelRecording
        +build(BuildContext) Widget
    }
    
    TranscriptionListScreen o-- TranscriptionListView : contains
    TranscriptionListView o-- TranscriptionItemWidget : contains
    TranscriptionItemWidget o-- AudioPlayerControlWidget : contains when selected
    TranscriptionListScreen o-- AudioRecordingWidget : contains
```

## Data Flow Diagrams

### Application Startup

```mermaid
sequenceDiagram
    participant Screen as TranscriptionListScreen
    participant Cubit as TranscriptionCubit
    participant Repo as TranscriptionRepositoryImpl
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
    participant Repo as TranscriptionRepositoryImpl
    participant AudioPlayer as AudioPlayerImpl
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
    Cubit->>AudioPlayer: play(filePath)
    AudioPlayer->>JustAudio: setFilePath(filePath)
    AudioPlayer->>JustAudio: play()
    
    %% Playback updates
    JustAudio-->>AudioPlayer: position/state updates
    AudioPlayer-->>Cubit: PlaybackState stream updates
    Cubit->>Cubit: emit state with updated position/state
    Cubit-->>Player: rebuild with new position/state
    
    %% Seek interaction
    User->>Player: drag seek bar
    Player->>Player: update local position
    User->>Player: release seek bar
    Player->>Cubit: seekTo(position)
    Cubit->>AudioPlayer: seekTo(position)
    AudioPlayer->>JustAudio: seek(position)
```

### Audio Recording

```mermaid
sequenceDiagram
    participant User as User
    participant RecordUI as AudioRecordingWidget
    participant RecordCubit as RecordingCubit
    participant Recorder as AudioRecorderImpl
    participant FS as FileSystem
    participant Repo as TranscriptionRepositoryImpl
    
    %% Start recording
    User->>RecordUI: tap record button
    RecordUI->>RecordCubit: startRecording()
    RecordCubit->>FS: generateFilePath(".m4a")
    FS-->>RecordCubit: filePath
    RecordCubit->>Recorder: startRecording(filePath)
    Recorder-->>RecordCubit: RecordingState.RECORDING stream update
    RecordCubit->>RecordCubit: emit state with recordingState
    RecordCubit-->>RecordUI: update UI with recordingState
    
    %% Level updates during recording
    Recorder-->>RecordCubit: audio level updates
    RecordCubit->>RecordCubit: emit state with updated level
    RecordCubit-->>RecordUI: update UI with audio level
    
    %% Stop recording
    User->>RecordUI: tap stop button
    RecordUI->>RecordCubit: stopRecording()
    RecordCubit->>Recorder: stopRecording()
    Recorder-->>RecordCubit: filePath
    RecordCubit->>RecordCubit: emit state with RecordingState.STOPPED
    
    %% Save recording
    User->>RecordUI: tap save button
    RecordUI->>RecordCubit: saveRecording()
    RecordCubit->>Repo: createLocalTranscription(filePath)
    Repo->>Repo: generate pending Transcription
    Repo-->>RecordCubit: Transcription object
    RecordCubit->>RecordCubit: emit initial state (reset)
    
    %% Optionally initiate transcription
    RecordCubit->>Repo: uploadForTranscription(id)
    Repo->>Repo: mark for background upload
```

## Dependency Injection

```mermaid
graph TB
    subgraph DI [Dependency Injection Container]
        direction TB
        JA[just_audio.AudioPlayer]
        Rec[Recorder]
        FS[FileSystem]
        API[ApiClient]
        DB[LocalStorage]
        AP[AudioPlayerImpl]
        AR[AudioRecorderImpl]
        Repo[TranscriptionRepositoryImpl]
        TCubit[TranscriptionCubit]
        RCubit[RecordingCubit]
    end
    
    subgraph UI [UI Components]
        Screen[TranscriptionListScreen]
    end
    
    JA --> AP
    Rec --> AR
    FS --> Repo
    API --> Repo
    DB --> Repo
    
    AP --> TCubit
    Repo --> TCubit
    AR --> RCubit
    Repo --> RCubit
    FS --> RCubit
    
    TCubit --> Screen
    RCubit --> Screen
    
    %% Registration
    DI -- "register singleton" --> JA
    DI -- "register singleton" --> Rec
    DI -- "register singleton" --> FS
    DI -- "register singleton" --> API
    DI -- "register singleton" --> DB
    DI -- "register as AudioPlayer" --> AP
    DI -- "register as AudioRecorder" --> AR
    DI -- "register as TranscriptionRepository" --> Repo
    DI -- "register singleton/factory" --> TCubit
    DI -- "register singleton/factory" --> RCubit
    
    %% Styling
    classDef di fill:#d5e8d4,stroke:#82b366,stroke-width:1px
    classDef ui fill:#dae8fc,stroke:#6c8ebf,stroke-width:1px
    
    class DI,JA,Rec,FS,API,DB,AP,AR,Repo,TCubit,RCubit di
    class UI,Screen ui
```

## Key Architectural Improvements

1. **Proper Separation of Concerns**:
   - Domain layer contains only business logic, entities, and interfaces
   - Audio implementation details (both playback and recording) moved to the Data layer
   - No infrastructure implementation details leak into the Domain layer

2. **Complete Functionality**:
   - Full recording functionality properly represented
   - Clear separation between recording and playback concerns
   - Proper flow for creating new transcriptions

3. **Clean Interfaces at Boundaries**:
   - Domain defines what capabilities are needed through interfaces
   - Data layer implements those interfaces with concrete implementations
   - No direct dependencies on external libraries from Domain or Cubits

4. **Testability**:
   - All Cubits depend only on interfaces
   - Easy to mock AudioPlayer, AudioRecorder and TranscriptionRepository for testing
   - No need to mock external dependencies directly in tests

5. **Minimal Architecture**:
   - No unnecessary abstraction layers
   - Direct, straightforward data flow
   - Interfaces only where they provide real value (at layer boundaries)

This revised architecture maintains proper Clean Architecture principles while eliminating unnecessary complexity. It ensures dependencies point inward toward the Domain layer while keeping the implementation minimal and focused, and now includes the complete recording functionality needed for a transcription application. 