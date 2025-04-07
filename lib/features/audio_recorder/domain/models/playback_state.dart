import 'package:equatable/equatable.dart';

/// Represents the state of the audio playback at any given time.
class PlaybackState extends Equatable {
  /// The file path of the audio currently loaded or playing. Null if none.
  final String? currentFilePath;

  /// True if audio is currently playing.
  final bool isPlaying;

  /// True if audio is loading (e.g., buffering).
  final bool isLoading;

  /// True if playback has completed.
  final bool isCompleted;

  /// True if an error occurred during playback.
  final bool hasError;

  /// The error message, if [hasError] is true.
  final String? errorMessage;

  /// The current playback position.
  final Duration position;

  /// The total duration of the loaded audio file.
  final Duration totalDuration;

  /// Creates a new instance of [PlaybackState].
  const PlaybackState({
    this.currentFilePath,
    required this.isPlaying,
    required this.isLoading,
    required this.isCompleted,
    required this.hasError,
    this.errorMessage,
    required this.position,
    required this.totalDuration,
  });

  /// Represents the initial/default state before any playback starts.
  const PlaybackState.initial()
    : currentFilePath = null,
      isPlaying = false,
      isLoading = false,
      isCompleted = false,
      hasError = false,
      errorMessage = null,
      position = Duration.zero,
      totalDuration = Duration.zero;

  @override
  List<Object?> get props => [
    currentFilePath,
    isPlaying,
    isLoading,
    isCompleted,
    hasError,
    errorMessage,
    position,
    totalDuration,
  ];

  /// Creates a copy of this state but with the given fields replaced with the new values.
  PlaybackState copyWith({
    String? currentFilePath,
    bool? isPlaying,
    bool? isLoading,
    bool? isCompleted,
    bool? hasError,
    String? errorMessage,
    Duration? position,
    Duration? totalDuration,
    bool clearError = false,
    bool clearCurrentFilePath = false,
  }) {
    return PlaybackState(
      currentFilePath:
          clearCurrentFilePath ? null : currentFilePath ?? this.currentFilePath,
      isPlaying: isPlaying ?? this.isPlaying,
      isLoading: isLoading ?? this.isLoading,
      isCompleted: isCompleted ?? this.isCompleted,
      hasError: clearError ? false : (hasError ?? this.hasError),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      position: position ?? this.position,
      totalDuration: totalDuration ?? this.totalDuration,
    );
  }
}
