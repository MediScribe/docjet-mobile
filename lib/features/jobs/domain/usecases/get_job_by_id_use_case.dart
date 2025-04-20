import 'package:dartz/dartz.dart';
import 'package:docjet_mobile/core/error/failures.dart';
import 'package:docjet_mobile/core/usecases/usecase.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job.dart';
import 'package:docjet_mobile/features/jobs/domain/repositories/job_repository.dart';
import 'package:equatable/equatable.dart';

/// Use case for fetching a single job by its local ID.
class GetJobByIdUseCase implements UseCase<Job, GetJobByIdParams> {
  final JobRepository repository;

  GetJobByIdUseCase(this.repository);

  @override
  Future<Either<Failure, Job>> call(GetJobByIdParams params) async {
    return await repository.getJobById(params.localId);
  }
}

/// Parameters required for the [GetJobByIdUseCase].
class GetJobByIdParams extends Equatable {
  final String localId;

  const GetJobByIdParams({required this.localId});

  @override
  List<Object> get props => [localId];
}
