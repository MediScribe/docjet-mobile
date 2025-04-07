import 'package:docjet_mobile/features/audio_recorder/domain/entities/transcription_status.dart';
import 'package:equatable/equatable.dart';
import 'package:hive_flutter/hive_flutter.dart';

part 'local_job.g.dart'; // Name follows convention: original_filename.g.dart

/// A simple Data Transfer Object (DTO) / entity representing the essential
/// information about a locally recorded audio file that needs to be persisted
/// before or during the backend transcription process.
///
/// This is typically stored using the `LocalJobStore` (e.g., in Hive).
@HiveType(typeId: 0) // Unique ID for this Hive object type
class LocalJob extends Equatable {
  /// The path to the audio file on the local device.
  /// Acts as the primary key for local identification.
  @HiveField(0)
  final String localFilePath;

  /// Duration of the audio recording in milliseconds, captured once locally
  /// after the recording is finished.
  @HiveField(1)
  final int durationMillis;

  /// The last known status of this job from a local perspective.
  /// Examples: `created` (initial state), `submitted` (upload attempted),
  /// `error` (upload failed before backend confirmation).
  /// Stored as index by Hive generator.
  @HiveField(2)
  final TranscriptionStatus status;

  /// Timestamp when the recording was saved locally.
  /// Useful for ordering or FIFO processing of uploads.
  @HiveField(3)
  final DateTime localCreatedAt;

  /// The backend-assigned unique identifier (UUID) for the job.
  /// This is nullable and will only be populated *after* a successful
  /// upload confirmation from the backend API.
  @HiveField(4)
  final String? backendId;

  const LocalJob({
    required this.localFilePath,
    required this.durationMillis,
    required this.status,
    required this.localCreatedAt,
    this.backendId,
  });

  @override
  List<Object?> get props => [
    localFilePath,
    durationMillis,
    status,
    localCreatedAt,
    backendId,
  ];

  @override
  bool? get stringify => true; // For easier debugging with Equatable
}
