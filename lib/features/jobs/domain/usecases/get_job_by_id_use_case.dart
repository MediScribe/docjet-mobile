import 'package:dartz/dartz.dart';
import 'package:docjet_mobile/core/error/failures.dart';
import 'package:docjet_mobile/core/usecases/usecase.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job.dart';
import 'package:docjet_mobile/features/jobs/domain/repositories/job_repository.dart';

/// Use case for fetching a single job by its local ID.
class GetJobByIdUseCase implements UseCase<Job?, String> {
  final JobRepository repository;

  GetJobByIdUseCase({required this.repository});

  @override
  Future<Either<Failure, Job?>> call(String params) async {
    return await repository.getJobById(params);
  }
}
