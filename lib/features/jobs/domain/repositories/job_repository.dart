import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/job.dart';

// Abstract interface defining the contract for Job data operations.
// The domain layer depends on this, implementations are in the data layer.
abstract class JobRepository {
  /// Fetches all jobs for the current user.
  /// Returns [Right<List<Job>>] on success.
  /// Returns [Left<Failure>] on failure (e.g., ServerFailure, CacheFailure).
  Future<Either<Failure, List<Job>>> getJobs();

  /// Fetches a single job by its ID.
  /// Returns [Right<Job>] if found.
  /// Returns [Left<Failure>] if not found or on other errors.
  Future<Either<Failure, Job>> getJobById(String id);

  /// Creates a new job.
  /// Takes the path to the locally stored [audioFilePath] and optional [text].
  /// Returns the newly created [Right<Job>] on success (potentially with status 'created' or 'submitted').
  /// Returns [Left<Failure>] on failure.
  Future<Either<Failure, Job>> createJob({
    required String audioFilePath,
    String? text,
    // userId is handled by the implementation
  });

  // TODO: Define methods for updating or deleting jobs if needed later based on UI requirements.

  /// Attempts to synchronize locally pending jobs with the remote server.
  /// Fetches jobs marked as `SyncStatus.pending` from the local cache,
  /// sends them to the remote data source, and updates their local status
  /// (e.g., to `synced` or `error`) based on the outcome.
  /// Returns [Right(unit)] on success (even if some individual jobs failed to sync but the overall process completed).
  /// Returns [Left<Failure>] if a critical error occurs during the process (e.g., unable to reach remote).
  Future<Either<Failure, void>> syncPendingJobs();
}
