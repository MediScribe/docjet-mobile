import 'package:equatable/equatable.dart';

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

abstract class AudioRecorderState extends Equatable {
  const AudioRecorderState();

  @override
  List<Object?> get props => [];
}

class AudioRecorderInitial extends AudioRecorderState {}

class AudioRecorderReady extends AudioRecorderState {}

class AudioRecorderLoading extends AudioRecorderState {}

class AudioRecorderPermissionDenied extends AudioRecorderState {}

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

class AudioRecorderPaused extends AudioRecorderState {
  final String filePath;
  final Duration duration;

  const AudioRecorderPaused({required this.filePath, required this.duration});

  @override
  List<Object?> get props => [filePath, duration];
}

class AudioRecorderStopped extends AudioRecorderState {
  final AudioRecordState record;

  const AudioRecorderStopped({required this.record});

  @override
  List<Object?> get props => [record];
}

class AudioRecorderListLoaded extends AudioRecorderState {
  final List<AudioRecordState> recordings;

  const AudioRecorderListLoaded({required this.recordings});

  @override
  List<Object?> get props => [recordings];
}

class AudioRecorderError extends AudioRecorderState {
  final String message;

  const AudioRecorderError(this.message);

  @override
  List<Object?> get props => [message];
}
