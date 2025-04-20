import 'package:dartz/dartz.dart';
import 'package:docjet_mobile/core/error/failures.dart';
import 'package:docjet_mobile/core/usecases/usecase.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job_update_details.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job.dart';
import 'package:docjet_mobile/features/jobs/domain/repositories/job_repository.dart';
import 'package:equatable/equatable.dart';

/// Use case for updating an existing job.
class UpdateJobUseCase implements UseCase<Job, UpdateJobParams> {
  final JobRepository repository;

  UpdateJobUseCase(this.repository);

  @override
  Future<Either<Failure, Job>> call(UpdateJobParams params) async {
    return await repository.updateJob(
      localId: params.localId,
      updates: params.updates,
    );
  }
}

/// Parameters required for the [UpdateJobUseCase].
class UpdateJobParams extends Equatable {
  final String localId;
  final JobUpdateDetails updates;

  const UpdateJobParams({required this.localId, required this.updates});

  @override
  List<Object> get props => [localId, updates];
}
