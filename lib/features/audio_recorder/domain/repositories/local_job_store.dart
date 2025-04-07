import 'package:docjet_mobile/features/audio_recorder/domain/entities/local_job.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/entities/transcription_status.dart';

/// Interface for storing and retrieving information about local audio jobs.
///
/// This abstraction allows for different persistence mechanisms (e.g., Hive, SharedPreferences).
/// It focuses on managing the state of recordings *before* they are confirmed by the backend
/// or when tracking local details alongside backend information.
abstract class LocalJobStore {
  /// Saves or updates a local job record.
  ///
  /// Uses `localFilePath` as the primary key internally.
  /// If a job with the same path exists, it should be overwritten.
  Future<void> saveJob(LocalJob job);

  /// Retrieves a single local job record by its file path.
  ///
  /// Returns `null` if no job is found for the given path.
  Future<LocalJob?> getJob(String localFilePath);

  /// Retrieves all local jobs that are considered "offline" or pending upload.
  ///
  /// Typically, this means jobs with a status like `created` or potentially
  /// a failed upload status that needs retry.
  Future<List<LocalJob>> getOfflineJobs();

  /// Retrieves all locally stored job records, regardless of status.
  ///
  /// Useful for merging with backend data or for cleanup tasks.
  Future<List<LocalJob>> getAllLocalJobs();

  /// Updates the status of a local job and optionally stores the backend ID.
  ///
  /// This is crucial after a successful upload attempt where the backend
  /// confirms the job creation and returns its unique ID.
  ///
  /// - `localFilePath`: Identifies the local job record to update.
  /// - `status`: The new `TranscriptionStatus` to set.
  /// - `backendId`: The optional backend-generated UUID for the job.
  Future<void> updateJobStatus(
    String localFilePath,
    TranscriptionStatus status, {
    String? backendId,
  });

  /// Deletes a local job record.
  ///
  /// Should be called when the corresponding audio file is deleted or when
  /// the job is confirmed to be fully processed and removed from the backend.
  Future<void> deleteJob(String localFilePath);
}
