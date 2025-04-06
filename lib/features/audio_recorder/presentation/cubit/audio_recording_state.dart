import 'package:equatable/equatable.dart';

// Base class
abstract class AudioRecordingState extends Equatable {
  const AudioRecordingState();

  @override
  List<Object?> get props => [];
}

// Initial/Idle State (before permission check)
class AudioRecordingInitial extends AudioRecordingState {}

// Loading State (for async operations like start, stop, permission)
class AudioRecordingLoading extends AudioRecordingState {}

// Error State
class AudioRecordingError extends AudioRecordingState {
  final String message;

  const AudioRecordingError(this.message);

  @override
  List<Object?> get props => [message];
}

// Permission Denied State
class AudioRecordingPermissionDenied extends AudioRecordingState {}

// Ready State (Permission granted, idle, ready to record)
class AudioRecordingReady extends AudioRecordingState {
  const AudioRecordingReady();
}

// Recording State
class AudioRecordingInProgress extends AudioRecordingState {
  final String filePath;
  final Duration duration;

  const AudioRecordingInProgress({
    required this.filePath,
    required this.duration,
  });

  @override
  List<Object?> get props => [filePath, duration];
}

// Paused State
class AudioRecordingPaused extends AudioRecordingState {
  final String filePath;
  final Duration duration;

  const AudioRecordingPaused({required this.filePath, required this.duration});

  @override
  List<Object?> get props => [filePath, duration];
}

// Stopped State (After successful recording, might be transient)
class AudioRecordingStopped extends AudioRecordingState {
  final String resultingFilePath; // Pass the final path if needed downstream
  const AudioRecordingStopped(this.resultingFilePath);

  @override
  List<Object?> get props => [resultingFilePath];
}
