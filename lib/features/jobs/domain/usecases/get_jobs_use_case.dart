import 'package:dartz/dartz.dart';
import 'package:docjet_mobile/core/error/failures.dart';
import 'package:docjet_mobile/core/usecases/usecase.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job.dart';
import 'package:docjet_mobile/features/jobs/domain/repositories/job_repository.dart';

/// Use case for fetching the list of all jobs.
class GetJobsUseCase implements UseCase<List<Job>, NoParams> {
  final JobRepository repository;

  GetJobsUseCase(this.repository);

  @override
  Future<Either<Failure, List<Job>>> call(NoParams params) async {
    // Delegates directly to the repository method
    return await repository.getJobs();
  }
}
