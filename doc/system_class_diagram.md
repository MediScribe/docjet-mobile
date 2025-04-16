# DocJet Mobile System Class Diagram

This document provides a comprehensive visualization of the DocJet Mobile system architecture through class diagrams at multiple levels of detail.

## Table of Contents
1. [System Overview](#system-overview)
2. [Core Infrastructure](#core-infrastructure)
3. [Audio Recording System](#audio-recording-system)
4. [Audio Playback System](#audio-playback-system)
5. [Transcription System](#transcription-system)
6. [UI Components and State Management](#ui-components-and-state-management)

## System Overview

This diagram shows the high-level components of the system and their relationships, organized by architectural layers.

```mermaid
classDiagram
    %% Layer definitions
    namespace Presentation {
        class UI_Components["UI Components"] {
            Pages, Widgets, etc.
        }
        class State_Management["State Management"] {
            Cubits, States
        }
    }
    
    namespace Domain {
        class Entities["Domain Entities"] {
            Business objects and value objects
        }
        class Repositories["Repository Interfaces"] {
            Abstract contracts for data access
        }
        class Services["Domain Services"] {
            Business logic interfaces
        }
    }
    
    namespace Data {
        class Repositories_Impl["Repository Implementations"] {
            Concrete implementations of repositories
        }
        class DataSources["Data Sources"] {
            Local and remote data access
        }
        class Services_Impl["Service Implementations"] {
            Concrete implementations of services
        }
    }
    
    namespace Infrastructure {
        class Platform_Abstractions["Platform Abstractions"] {
            File system, permissions, paths
        }
        class External_Adapters["External Adapters"] {
            Adapters for external libraries
        }
        class Storage["Local Storage"] {
            Hive database, local caching
        }
    }
    
    %% Relationships between layers
    Presentation.UI_Components --> Presentation.State_Management : uses
    Presentation.State_Management --> Domain.Repositories : depends on
    Presentation.State_Management --> Domain.Services : depends on
    
    Domain.Repositories ..> Domain.Entities : uses
    Domain.Services ..> Domain.Entities : uses
    
    Data.Repositories_Impl ..|> Domain.Repositories : implements
    Data.Services_Impl ..|> Domain.Services : implements
    Data.Repositories_Impl --> Data.DataSources : uses
    Data.Services_Impl --> Data.DataSources : uses
    
    Data.DataSources --> Infrastructure.Platform_Abstractions : uses
    Data.DataSources --> Infrastructure.Storage : uses
    Data.Services_Impl --> Infrastructure.External_Adapters : uses
    
    %% System-level annotations
    note for Presentation.UI_Components "Flutter widgets, pages, and components that users interact with"
    note for Presentation.State_Management "BLoC/Cubit pattern for UI state management"
    note for Domain.Entities "Core business objects independent of implementation details"
    note for Domain.Repositories "Contracts that define data operations"
    note for Infrastructure.Platform_Abstractions "Interfaces for platform-specific functionality"
```

## Core Infrastructure

The core infrastructure provides foundational services used by all features.

```mermaid
classDiagram
    %% External Dependencies
    class DartIO["dart:io"] {
        <<External Library>>
        Platform file system access
    }
    
    class PathProvider["path_provider"] {
        <<External Library>>
        System directories access
    }
    
    class PermissionHandler["permission_handler"] {
        <<External Library>>
        Permission management
    }
    
    class Hive["hive"] {
        <<External Library>>
        NoSQL database
    }
    
    %% Core Interfaces
    class FileSystem {
        <<interface>>
        File system operations interface
        +fileExists()
        +readFile()
        +writeFile()
    }
    
    class PathProvider["PathProvider"] {
        <<interface>>
        Directory access interface
        +getApplicationDocumentsDirectory()
    }
    
    class PathResolver {
        <<interface>>
        Path resolution interface
        +resolve()
    }
    
    class PermissionHandler["PermissionHandler"] {
        <<interface>>
        Permission management interface
        +request()
        +status()
    }
    
    class LocalJobStore {
        <<interface>>
        Local storage interface for jobs
        +saveJob()
        +getJobs()
    }
    
    %% Implementations
    class IoFileSystem {
        Concrete file system implementation
        -_resolvePath()
    }
    
    class AppPathProvider {
        Concrete path provider implementation
    }
    
    class PathResolverImpl {
        Concrete path resolver implementation
    }
    
    class AppPermissionHandler {
        Concrete permission handler implementation
    }
    
    class HiveLocalJobStoreImpl {
        Hive-based job storage implementation
    }
    
    %% Relationships
    IoFileSystem ..|> FileSystem : implements
    AppPathProvider ..|> PathProvider : implements
    PathResolverImpl ..|> PathResolver : implements
    AppPermissionHandler ..|> PermissionHandler : implements
    HiveLocalJobStoreImpl ..|> LocalJobStore : implements
    
    IoFileSystem --> DartIO : uses
    AppPathProvider --> PathProvider : uses
    AppPermissionHandler --> PermissionHandler : uses
    HiveLocalJobStoreImpl --> Hive : uses
    
    IoFileSystem --> AppPathProvider : uses
    PathResolverImpl --> AppPathProvider : uses
```

## Audio Recording System

This diagram shows the classes involved in the audio recording feature.

```mermaid
classDiagram
    %% External Dependency
    class RecordPackage["record"] {
        <<External Library>>
        Low-level audio recording
    }
    
    %% Domain Layer
    class AudioRecord {
        Core business entity for recordings
        +String filePath
        +Duration duration
        +DateTime createdAt
    }
    
    class AudioRecorderRepository {
        <<interface>>
        Recording operations contract
        +checkPermission()
        +startRecording()
        +stopRecording()
        +pauseRecording()
    }
    
    %% Data Layer
    class AudioRecorderRepositoryImpl {
        Implementation of repository
        Orchestrates data sources
    }
    
    class AudioLocalDataSource {
        <<interface>>
        Local recording operations
        +startRecording()
        +stopRecording()
    }
    
    class AudioLocalDataSourceImpl {
        Implementation using record package
    }
    
    class AudioFileManager {
        <<interface>>
        Audio file handling
        +listRecordingPaths()
        +deleteRecording()
    }
    
    class AudioFileManagerImpl {
        Implementation for file operations
    }
    
    class AudioConcatenationService {
        <<interface>>
        For merging audio files
        +concatenate()
    }
    
    %% Presentation Layer
    class AudioRecordingCubit {
        Recording state management
        +checkPermission()
        +startRecording()
        +stopRecording()
    }
    
    class AudioRecordingState {
        <<abstract>>
        Base state for recording
    }
    
    class AudioRecordingInitial {
        Initial recording state
    }
    
    class AudioRecordingReady {
        Ready to record state
    }
    
    class AudioRecordingInProgress {
        Currently recording state
        +Duration elapsed
    }
    
    %% Relationships
    AudioRecordingCubit --> AudioRecorderRepository : uses
    AudioRecordingCubit --> AudioRecordingState : manages
    AudioRecordingInitial --|> AudioRecordingState : extends
    AudioRecordingReady --|> AudioRecordingState : extends
    AudioRecordingInProgress --|> AudioRecordingState : extends
    
    AudioRecorderRepositoryImpl ..|> AudioRecorderRepository : implements
    AudioRecorderRepositoryImpl --> AudioLocalDataSource : uses
    AudioRecorderRepositoryImpl --> AudioFileManager : uses
    
    AudioLocalDataSourceImpl ..|> AudioLocalDataSource : implements
    AudioLocalDataSourceImpl --> RecordPackage : uses
    AudioLocalDataSourceImpl --> FileSystem : uses
    AudioLocalDataSourceImpl --> PermissionHandler : uses
    AudioLocalDataSourceImpl --> AudioConcatenationService : uses
    
    AudioFileManagerImpl ..|> AudioFileManager : implements
    AudioFileManagerImpl --> FileSystem : uses
    AudioFileManagerImpl --> PathProvider : uses
    
    note for AudioRecorderRepository "Core abstraction for recording operations"
    note for AudioRecord "Value object representing a recording"
    note for AudioRecordingCubit "Manages UI state for recording screen"
```

## Audio Playback System

This diagram shows the classes involved in the audio playback feature.

```mermaid
classDiagram
    %% External Dependency
    class JustAudio["just_audio"] {
        <<External Library>>
        Low-level audio playback
    }
    
    %% Domain Layer
    class DomainPlayerState {
        <<enumeration>>
        Playback states independent of implementation
        +initial
        +loading
        +playing
        +paused
        +stopped
        +completed
        +error
    }
    
    class PlaybackState {
        <<freezed>>
        Complete playback state
        +initial()
        +loading()
        +playing()
        +paused()
        +stopped()
        +completed()
        +error()
    }
    
    class AudioPlayerAdapter {
        <<interface>>
        Audio player abstraction
        +setSourceUrl()
        +pause()
        +resume()
        +seek()
        +dispose()
    }
    
    class AudioPlaybackService {
        <<interface>>
        High-level playback service
        +play()
        +pause()
        +resume()
        +seek()
    }
    
    class PlaybackStateMapper {
        <<interface>>
        Maps raw states to domain states
        +playbackStateStream
    }
    
    %% Data Layer
    class AudioPlayerAdapterImpl {
        Implementation using just_audio
        -_setupInternalListeners()
    }
    
    class AudioPlaybackServiceImpl {
        Implementation of playback service
    }
    
    class PlaybackStateMapperImpl {
        Implementation using RxDart
        -_createCombinedStream()
        -_constructState()
    }
    
    %% Presentation Layer
    class AudioListCubit {
        Manages audio list and playback
        +loadAudioRecordings()
        +playRecording()
        +pausePlayback()
    }
    
    class AudioListState {
        <<abstract>>
        Base state for audio list
    }
    
    class AudioListLoaded {
        Loaded state with recordings
        +List~AudioRecord~ recordings
        +PlaybackInfo playbackInfo
    }
    
    class PlaybackInfo {
        UI-friendly playback state
        +bool isPlaying
        +Duration position
    }
    
    %% Relationships
    AudioListCubit --> AudioRecorderRepository : uses
    AudioListCubit --> AudioPlaybackService : uses
    AudioListCubit --> AudioListState : manages
    AudioListLoaded --|> AudioListState : extends
    
    AudioPlayerAdapterImpl ..|> AudioPlayerAdapter : implements
    AudioPlayerAdapterImpl --> JustAudio : uses
    AudioPlayerAdapterImpl --> PathResolver : uses
    
    AudioPlaybackServiceImpl ..|> AudioPlaybackService : implements
    AudioPlaybackServiceImpl --> AudioPlayerAdapter : uses
    AudioPlaybackServiceImpl --> PlaybackStateMapper : uses
    
    PlaybackStateMapperImpl ..|> PlaybackStateMapper : implements
    PlaybackStateMapperImpl --> DomainPlayerState : consumes
    PlaybackStateMapperImpl --> PlaybackState : produces
    
    AudioPlaybackService ..> PlaybackState : returns
    
    note for AudioPlayerAdapter "Isolates the application from the specific audio player implementation"
    note for PlaybackStateMapper "Transforms raw player events into unified domain states"
    note for AudioPlaybackService "Orchestrates playback operations with high-level API"
```

## Transcription System

This diagram shows the classes involved in the transcription feature.

```mermaid
classDiagram
    %% Domain Layer
    class Transcription {
        Core business entity for transcriptions
        +String? id
        +String localFilePath
        +TranscriptionStatus status
        +String? displayTitle
        +String? displayText
    }
    
    class TranscriptionStatus {
        <<enumeration>>
        Status of transcription job
        +created
        +uploading
        +processing
        +completed
        +failed
    }
    
    class LocalJob {
        Persistent representation of jobs
        +String id
        +String localFilePath
        +TranscriptionStatus status
    }
    
    class TranscriptionRemoteDataSource {
        <<interface>>
        Remote API for transcriptions
        +uploadAudio()
        +getTranscriptionStatus()
    }
    
    class LocalJobStore {
        <<interface>>
        Storage for transcription jobs
        +saveJob()
        +getJobs()
    }
    
    class TranscriptionMergeService {
        <<interface>>
        Merges local and remote data
        +mergeTranscriptions()
    }
    
    %% Data Layer
    class FakeTranscriptionDataSourceImpl {
        Mock implementation for development
    }
    
    class HiveLocalJobStoreImpl {
        Hive-based job storage
    }
    
    class TranscriptionMergeServiceImpl {
        Implementation of merge logic
    }
    
    %% Repository Integration
    class AudioRecorderRepositoryImpl {
        Central coordinator
        +loadTranscriptions()
        +uploadRecording()
    }
    
    %% Relationships
    AudioRecorderRepositoryImpl --> TranscriptionRemoteDataSource : uses
    AudioRecorderRepositoryImpl --> LocalJobStore : uses
    AudioRecorderRepositoryImpl --> TranscriptionMergeService : uses
    
    FakeTranscriptionDataSourceImpl ..|> TranscriptionRemoteDataSource : implements
    HiveLocalJobStoreImpl ..|> LocalJobStore : implements
    TranscriptionMergeServiceImpl ..|> TranscriptionMergeService : implements
    
    TranscriptionMergeService ..> Transcription : produces
    LocalJobStore ..> LocalJob : manages
    TranscriptionRemoteDataSource ..> Transcription : returns
    
    note for Transcription "Client-side unified view of a recording job's state"
    note for TranscriptionMergeService "Combines local data with remote API responses"
    note for LocalJobStore "Persistent storage for tracking transcription jobs"
```

## UI Components and State Management

This diagram shows the presentation layer components and state management.

```mermaid
classDiagram
    %% Cubits
    class AudioListCubit {
        Manages list of recordings
        +loadAudioRecordings()
        +playRecording()
        +deleteRecording()
    }
    
    class AudioRecordingCubit {
        Manages recording process
        +checkPermission()
        +startRecording()
        +stopRecording()
    }
    
    %% States
    class AudioListState {
        <<abstract>>
        Base state for audio list
    }
    
    class AudioListInitial {
        Initial list state
    }
    
    class AudioListLoading {
        Loading state
    }
    
    class AudioListLoaded {
        Loaded state with data
        +List~AudioRecord~ recordings
        +PlaybackInfo playbackInfo
    }
    
    class AudioListError {
        Error state
        +String message
    }
    
    class AudioRecordingState {
        <<abstract>>
        Base state for recording
    }
    
    class AudioRecordingInitial {
        Initial recording state
    }
    
    class AudioRecordingLoading {
        Loading state
    }
    
    class AudioRecordingReady {
        Ready to record
    }
    
    class AudioRecordingInProgress {
        Currently recording
        +Duration elapsed
        +bool isPaused
    }
    
    class AudioRecordingError {
        Recording error
        +String message
    }
    
    %% Pages and Widgets
    class AudioRecorderListPage {
        Main list page
        Shows recordings
    }
    
    class AudioRecorderPage {
        Recording page
        Recording controls
    }
    
    class RecordingControls {
        Widget for recording buttons
    }
    
    class AudioListItem {
        Widget for single recording
    }
    
    %% Relationships
    AudioListCubit --> AudioListState : manages
    AudioRecordingCubit --> AudioRecordingState : manages
    
    AudioListInitial --|> AudioListState : extends
    AudioListLoading --|> AudioListState : extends
    AudioListLoaded --|> AudioListState : extends
    AudioListError --|> AudioListState : extends
    
    AudioRecordingInitial --|> AudioRecordingState : extends
    AudioRecordingLoading --|> AudioRecordingState : extends
    AudioRecordingReady --|> AudioRecordingState : extends
    AudioRecordingInProgress --|> AudioRecordingState : extends
    AudioRecordingError --|> AudioRecordingState : extends
    
    AudioRecorderListPage --> AudioListCubit : uses
    AudioRecorderPage --> AudioRecordingCubit : uses
    AudioRecorderListPage *-- AudioListItem : contains
    AudioRecorderPage *-- RecordingControls : contains
    
    note for AudioListCubit "Central state manager for the list screen"
    note for AudioRecordingCubit "Central state manager for the recording screen"
    note for AudioRecorderListPage "Main page showing all recordings and transcriptions"
```

Each diagram provides a different view of the system, focusing on specific functional areas while maintaining the layered architecture. The descriptions within each class and the notes help to explain the purpose and responsibility of key components. 