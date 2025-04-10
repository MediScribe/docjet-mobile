import 'package:docjet_mobile/features/audio_recorder/domain/entities/transcription_status.dart';
import 'package:equatable/equatable.dart'; // TODO: Add equatable dependency

/// Represents the client-side, unified view of a recording job's state.
///
/// This entity merges data persisted locally (via `LocalJobStore`,
/// especially for `created` status jobs using `localFilePath` as the key)
/// with data fetched from the backend API (identified by the `id` field
/// once available).
///
/// Its fields directly map to what the UI needs to show in the "Transkripte"
/// list, aligning with the `spec.md` and `architecture.md`.
class Transcription extends Equatable {
  /// Backend Job ID (UUID format). Nullable.
  /// Primary identifier *once* the job exists on the backend.
  /// Before that (status `created`), `localFilePath` is the key identifier
  /// for local management.
  final String? id;

  /// The path to the audio file on the local device.
  /// Primary key for local-only jobs.
  final String localFilePath;

  /// The current status of the transcription job.
  final TranscriptionStatus status;

  /// Timestamp when the recording was saved locally.
  /// Useful for FIFO processing if needed.
  final DateTime? localCreatedAt;

  /// Timestamp of job creation provided by the backend.
  final DateTime? backendCreatedAt;

  /// Timestamp of the last status update from the backend.
  final DateTime? backendUpdatedAt;

  /// Duration of the audio recording in milliseconds, measured locally
  /// post-recording and stored via `LocalJobStore`.
  final int? localDurationMillis;

  /// Duration of the audio recording in milliseconds, as reported by the backend.
  /// This should be prioritized if available.
  // final int? backendDurationMillis; // REMOVED: Backend does not provide duration per user feedback.

  /// A short title snippet generated by the backend (e.g., first few words).
  final String? displayTitle;

  /// A preview snippet of the transcribed text from the backend.
  final String? displayText;

  /// Backend error code if the job status is `failed`.
  final String? errorCode;

  /// Backend error message if the job status is `failed`.
  final String? errorMessage;

  const Transcription({
    this.id,
    required this.localFilePath,
    required this.status,
    this.localCreatedAt,
    this.backendCreatedAt,
    this.backendUpdatedAt,
    this.localDurationMillis,
    // this.backendDurationMillis, // REMOVED
    this.displayTitle,
    this.displayText,
    this.errorCode,
    this.errorMessage,
  });

  /// Helper to get the most appropriate duration for display.
  /// Prioritizes backend duration if available, otherwise falls back to local.
  int? get displayDurationMillis {
    // return backendDurationMillis ?? localDurationMillis; // UPDATED: Only local duration exists
    return localDurationMillis;
  }

  @override
  List<Object?> get props => [
    id,
    localFilePath,
    status,
    localCreatedAt,
    backendCreatedAt,
    backendUpdatedAt,
    localDurationMillis,
    // backendDurationMillis, // REMOVED
    displayTitle,
    displayText,
    errorCode,
    errorMessage,
  ];

  @override
  bool? get stringify => true; // For easier debugging with Equatable
}
