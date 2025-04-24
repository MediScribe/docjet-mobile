import 'package:docjet_mobile/features/jobs/domain/entities/job.dart';
import 'package:docjet_mobile/core/error/exceptions.dart';
import 'package:dartz/dartz.dart';

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
  /// The user ID is obtained internally from AuthSessionProvider.
  /// Requires path to the `audioFile`, and optional `text`.
  /// Throws a [ServerException] or [ApiException] for all error cases.
  Future<Job> createJob({
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

  /// Sends a list of locally created/modified jobs to the backend for synchronization.
  /// Typically used for offline-first scenarios.
  /// Input: A list of [Job] entities that need syncing (e.g., status = pending).
  /// Returns: A list of [Job] entities as they are after synchronization on the backend
  /// (potentially with updated IDs, statuses, timestamps).
  /// Throws: [ServerException] or [ApiException] if the batch sync fails.
  /// Note: The implementation needs to handle potential partial failures if the API supports it.
  Future<List<Job>> syncJobs(List<Job> jobsToSync);

  /// Deletes a job via the API using its server-assigned ID.
  /// Corresponds to `DELETE /api/v1/jobs/{id}`.
  /// Requires the `serverId` of the job to delete.
  /// Throws a [ServerException] or [ApiException] for all error cases.
  /// Returns `Unit` on success.
  Future<Unit> deleteJob(String serverId);

  // TODO: Define methods for GET /api/v1/jobs/{id}/documents if needed directly by this layer.
}
