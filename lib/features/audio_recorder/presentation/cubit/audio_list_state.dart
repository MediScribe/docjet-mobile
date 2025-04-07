part of 'audio_list_cubit.dart';

// Removed imports from here - they belong in audio_list_cubit.dart
// import 'package:docjet_mobile/features/audio_recorder/domain/entities/transcription.dart';
// import 'package:equatable/equatable.dart';

// Define PlaybackInfo helper class
class PlaybackInfo extends Equatable {
  final String? activeFilePath;
  final bool isPlaying;
  final bool isLoading;
  final Duration currentPosition;
  final Duration totalDuration;
  final String? error;

  const PlaybackInfo({
    this.activeFilePath,
    required this.isPlaying,
    required this.isLoading,
    required this.currentPosition,
    required this.totalDuration,
    this.error,
  });

  const PlaybackInfo.initial()
    : activeFilePath = null,
      isPlaying = false,
      isLoading = false,
      currentPosition = Duration.zero,
      totalDuration = Duration.zero,
      error = null;

  @override
  List<Object?> get props => [
    activeFilePath,
    isPlaying,
    isLoading,
    currentPosition,
    totalDuration,
    error,
  ];

  // Optional: Add copyWith if needed directly on PlaybackInfo
  PlaybackInfo copyWith({
    String? activeFilePath,
    bool? isPlaying,
    bool? isLoading,
    Duration? currentPosition,
    Duration? totalDuration,
    String? error,
    bool clearActiveFilePath = false,
    bool clearError = false,
  }) {
    return PlaybackInfo(
      activeFilePath:
          clearActiveFilePath ? null : activeFilePath ?? this.activeFilePath,
      isPlaying: isPlaying ?? this.isPlaying,
      isLoading: isLoading ?? this.isLoading,
      currentPosition: currentPosition ?? this.currentPosition,
      totalDuration: totalDuration ?? this.totalDuration,
      error: clearError ? null : error ?? this.error,
    );
  }
}

// Base class
abstract class AudioListState extends Equatable {
  const AudioListState();

  @override
  List<Object?> get props => [];
}

// Initial State
class AudioListInitial extends AudioListState {}

// Loading State
class AudioListLoading extends AudioListState {}

// Error State
class AudioListError extends AudioListState {
  final String message;

  const AudioListError({required this.message});

  @override
  List<Object> get props => [message];
}

// Loaded State - Now includes PlaybackInfo
class AudioListLoaded extends AudioListState {
  final List<Transcription> transcriptions;
  final PlaybackInfo playbackInfo;

  const AudioListLoaded({
    required this.transcriptions,
    this.playbackInfo = const PlaybackInfo.initial(),
  });

  @override
  List<Object?> get props => [transcriptions, playbackInfo];

  @override
  String toString() =>
      'AudioListLoaded { count: ${transcriptions.length}, playback: $playbackInfo }';

  AudioListLoaded copyWith({
    List<Transcription>? transcriptions,
    PlaybackInfo? playbackInfo,
  }) {
    return AudioListLoaded(
      transcriptions: transcriptions ?? this.transcriptions,
      playbackInfo: playbackInfo ?? this.playbackInfo,
    );
  }
}
