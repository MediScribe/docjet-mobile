import 'package:dartz/dartz.dart'; // TODO: Add dartz dependency
import 'package:docjet_mobile/core/error/failures.dart'; // Added import
// TODO: Define Failure hierarchy/ApiError
import 'package:docjet_mobile/features/audio_recorder/domain/entities/transcription.dart';

/// Interface for interacting with the backend transcription API.
///
/// Defines the contract for fetching job statuses and uploading recordings.
/// Implementations will handle HTTP communication (real) or provide fake data (testing).
/// Uses `Result` type (Either from dartz) for error handling.
abstract class TranscriptionRemoteDataSource {
  /// Fetches all transcription job records for the authenticated user from the backend.
  /// Corresponds to `GET /api/v1/jobs`.
  ///
  /// Returns a list of `Transcription` entities representing the backend state,
  /// or an `ApiError` on failure.
  Future<Either<ApiFailure, List<Transcription>>>
  getUserJobs(); // TODO: Rename ApiError -> ApiFailure

  /// Fetches the latest status and metadata for a single job by its backend ID.
  /// Corresponds to `GET /api/v1/jobs/{id}`.
  ///
  /// Returns a `Transcription` entity or an `ApiError`.
  Future<Either<ApiFailure, Transcription>> getTranscriptionJob(
    String backendId,
  );

  /// Uploads a local recording file for transcription.
  /// Corresponds to `POST /api/v1/jobs`.
  ///
  /// Takes the `localFilePath` and potentially other metadata (`userId`, text hints).
  /// Implementation MUST handle `multipart/form-data` encoding.
  /// The `userId` is required by the backend API.
  ///
  /// Returns the initial `Transcription` entity created by the backend upon successful submission,
  /// or an `ApiError`.
  Future<Either<ApiFailure, Transcription>> uploadForTranscription({
    required String localFilePath,
    required String
    userId, // Assuming userId is available, adjust sourcing as needed
    String? text,
    String? additionalText,
  });

  // Note: No method for PATCH /api/v1/jobs/{id} included, as per architecture.md rationale.
}
