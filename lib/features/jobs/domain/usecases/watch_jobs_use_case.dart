import 'package:dartz/dartz.dart';
import 'package:docjet_mobile/core/error/failures.dart';
import 'package:docjet_mobile/core/usecases/usecase.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job.dart';
import 'package:docjet_mobile/features/jobs/domain/repositories/job_repository.dart';

/// Use case that provides a stream of all jobs, which updates when job data changes.
///
/// This is useful for reactive UIs that need to reflect job state in real-time.
class WatchJobsUseCase implements StreamUseCase<List<Job>, NoParams> {
  final JobRepository repository;

  WatchJobsUseCase({required this.repository});

  /// Returns a stream of job lists.
  ///
  /// The stream emits a new value whenever the job collection changes.
  @override
  Stream<Either<Failure, List<Job>>> call(NoParams params) {
    return repository.watchJobs();
  }
}
