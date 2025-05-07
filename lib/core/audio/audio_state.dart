import 'package:equatable/equatable.dart';

/// Represents the possible phases of the audio recording and playback flow.
enum AudioPhase {
  /// No recording or playback is in progress.
  idle,

  /// Audio is being recorded.
  recording,

  /// Recording is paused.
  recordingPaused,

  /// Audio is being played.
  playing,

  /// Playback is paused.
  playingPaused,
}

/// Represents the state of the audio recording and playback.
///
/// This is the central state model used by AudioCubit to encapsulate
/// all information about the current audio session.
class AudioState extends Equatable {
  /// The current phase of the audio recording or playback.
  final AudioPhase phase;

  /// The current position of the recording or playback.
  final Duration position;

  /// The total duration of the audio file (for playback only).
  final Duration duration;

  /// The path to the recorded or loaded audio file.
  /// Will be null if no file has been created yet.
  final String? filePath;

  /// Creates a new [AudioState] instance.
  const AudioState({
    required this.phase,
    required this.position,
    required this.duration,
    this.filePath,
  });

  /// Initial state with no recording or playback.
  const AudioState.initial()
    : phase = AudioPhase.idle,
      position = Duration.zero,
      duration = Duration.zero,
      filePath = null;

  /// Creates a copy of this state with the given fields replaced.
  AudioState copyWith({
    AudioPhase? phase,
    Duration? position,
    Duration? duration,
    String? filePath,
    bool clearFilePath = false,
  }) {
    return AudioState(
      phase: phase ?? this.phase,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      filePath: clearFilePath ? null : (filePath ?? this.filePath),
    );
  }

  @override
  List<Object?> get props => [phase, position, duration, filePath];
}
