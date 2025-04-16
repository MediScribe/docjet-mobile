import 'package:docjet_mobile/features/jobs/domain/entities/job.dart';
import 'package:docjet_mobile/core/error/exceptions.dart';

// Abstract interface for interacting with the remote Job API.
// Defines the contract for fetching and creating jobs over the network.
abstract class JobRemoteDataSource {
  /// Fetches all job records for the authenticated user from the API.
  /// Corresponds to `GET /api/v1/jobs`.
  /// Throws a [ServerException] or [ApiException] for all error cases (4xx, 5xx, network errors).
  Future<List<Job>> fetchJobs();

  /// Fetches a single job record by its ID from the API.
  /// Corresponds to `GET /api/v1/jobs/{id}`.
  /// Throws a [ServerException] or [ApiException] for all error cases.
  Future<Job> fetchJobById(String id);

  /// Creates a new job via the API by uploading audio and metadata.
  /// Corresponds to `POST /api/v1/jobs`.
  /// Requires `userId`, path to the `audioFile`, and optional `text`.
  /// Throws a [ServerException] or [ApiException] for all error cases.
  Future<Job> createJob({
    required String
    userId, // User ID needs to be passed from the session/auth state
    required String audioFilePath,
    String? text,
    String? additionalText, // Added based on spec
  });

  /// Updates job metadata via the API.
  /// Corresponds to `PATCH /api/v1/jobs/{id}`.
  /// Requires the `jobId` and a map `updates` containing fields to update (e.g., {'text': '...', 'display_title': '...'}).
  /// Returns the updated [Job].
  /// Throws a [ServerException] or [ApiException] for all error cases.
  Future<Job> updateJob({
    required String jobId,
    required Map<String, dynamic> updates,
  });

  // TODO: Define methods for GET /api/v1/jobs/{id}/documents if needed directly by this layer.
}
