import 'package:docjet_mobile/features/audio_recorder/domain/entities/audio_record.dart';
import 'package:equatable/equatable.dart';

// Base class for all states - make it Equatable
abstract class AudioRecorderState extends Equatable {
  const AudioRecorderState();

  @override
  List<Object?> get props => []; // Default: no props
}

// Specific state entity representing a single recording for the UI
// TODO: Consider moving this to a presentation layer entities folder if it grows
class AudioRecordState extends Equatable {
  final String filePath;
  final Duration duration;
  final DateTime createdAt;

  const AudioRecordState({
    required this.filePath,
    required this.duration,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [filePath, duration, createdAt];
}

// Initial State
class AudioRecorderInitial extends AudioRecorderState {}

// Loading State
class AudioRecorderLoading extends AudioRecorderState {}

// Error State
class AudioRecorderError extends AudioRecorderState {
  final String message;

  const AudioRecorderError(this.message);

  @override
  List<Object?> get props => [message];
}

// Permission Denied State
class AudioRecorderPermissionDenied extends AudioRecorderState {}

// Ready State (Permission granted, idle)
class AudioRecorderReady extends AudioRecorderState {
  const AudioRecorderReady();
}

// Add the missing AudioRecorderLoaded state
class AudioRecorderLoaded extends AudioRecorderState {
  final List<AudioRecord> recordings;

  const AudioRecorderLoaded(this.recordings);

  @override
  List<Object> get props => [recordings];

  @override
  String toString() => 'AudioRecorderLoaded { count: ${recordings.length} }';
}

// Recording State
class AudioRecorderRecording extends AudioRecorderState {
  final String filePath;
  final Duration duration;

  const AudioRecorderRecording({
    required this.filePath,
    required this.duration,
  });

  @override
  List<Object?> get props => [filePath, duration];
}

// Paused State
class AudioRecorderPaused extends AudioRecorderState {
  final String filePath;
  final Duration duration;

  const AudioRecorderPaused({required this.filePath, required this.duration});

  @override
  List<Object?> get props => [filePath, duration];
}

// Stopped State (After successful recording)
class AudioRecorderStopped extends AudioRecorderState {
  const AudioRecorderStopped();
}

// State representing the list of loaded recordings
class AudioRecorderListLoaded extends AudioRecorderState {
  final List<AudioRecordState> recordings;

  const AudioRecorderListLoaded({required this.recordings});

  @override
  List<Object?> get props => [recordings];
}
