import 'package:dartz/dartz.dart';
import 'package:docjet_mobile/core/error/failures.dart';
import 'package:docjet_mobile/core/usecases/usecase.dart';
import 'package:docjet_mobile/features/jobs/domain/repositories/job_repository.dart';
import 'package:equatable/equatable.dart';

/// Use case for deleting (marking for deletion) a job.
class DeleteJobUseCase implements UseCase<Unit, DeleteJobParams> {
  final JobRepository repository;

  DeleteJobUseCase(this.repository);

  @override
  Future<Either<Failure, Unit>> call(DeleteJobParams params) async {
    return await repository.deleteJob(params.localId);
  }
}

/// Parameters required for the [DeleteJobUseCase].
class DeleteJobParams extends Equatable {
  final String localId;

  const DeleteJobParams({required this.localId});

  @override
  List<Object> get props => [localId];
}
