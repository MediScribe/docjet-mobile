import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:docjet_mobile/core/error/failures.dart';
import 'package:docjet_mobile/core/usecases/usecase.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job.dart';
import 'package:docjet_mobile/features/jobs/domain/repositories/job_repository.dart';

/// Use case that provides a stream of a specific job, which updates when the job changes.
///
/// This is useful for reactive UIs that need to reflect job state in real-time.
class WatchJobByIdUseCase implements StreamUseCase<Job?, WatchJobParams> {
  final JobRepository repository;

  WatchJobByIdUseCase({required this.repository});

  /// Returns a stream that emits the job with the given localId whenever it changes.
  ///
  /// @param params WatchJobParams containing the localId to watch
  /// @return a Stream that emits Either&lt;Failure, Job?&gt; where Job? will be null if the job is deleted
  @override
  Stream<Either<Failure, Job?>> call(WatchJobParams params) {
    return repository.watchJobById(params.localId);
  }
}

/// Parameters for the WatchJobByIdUseCase
class WatchJobParams extends Equatable {
  final String localId;

  const WatchJobParams({required this.localId});

  @override
  List<Object?> get props => [localId];
}
