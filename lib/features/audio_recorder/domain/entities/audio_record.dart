import 'package:equatable/equatable.dart';

/// Represents a single audio recording.
class AudioRecord extends Equatable {
  final String filePath;
  final Duration duration;
  final DateTime createdAt;

  const AudioRecord({
    required this.filePath,
    required this.duration,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [filePath, duration, createdAt];
}
