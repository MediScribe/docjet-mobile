import 'package:dartz/dartz.dart';
import 'package:docjet_mobile/core/error/failures.dart';
import 'package:docjet_mobile/core/usecases/usecase.dart';
import 'package:docjet_mobile/features/jobs/domain/repositories/job_repository.dart';
import 'package:equatable/equatable.dart';

/// Use case for resetting a job stuck in the SyncStatus.failed state.
class ResetFailedJobUseCase implements UseCase<Unit, ResetFailedJobParams> {
  final JobRepository repository;

  ResetFailedJobUseCase(this.repository);

  @override
  Future<Either<Failure, Unit>> call(ResetFailedJobParams params) async {
    // Implementation will call repository.resetFailedJob
    return await repository.resetFailedJob(params.localId);
  }
}

/// Parameters required for the [ResetFailedJobUseCase].
class ResetFailedJobParams extends Equatable {
  final String localId;

  const ResetFailedJobParams({required this.localId});

  @override
  List<Object> get props => [localId];
}
