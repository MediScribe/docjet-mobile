import 'package:dartz/dartz.dart';
import 'package:docjet_mobile/core/error/failures.dart';
import 'package:docjet_mobile/core/usecases/usecase.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job.dart';
import 'package:docjet_mobile/features/jobs/domain/repositories/job_repository.dart';
import 'package:equatable/equatable.dart';

/// Use case for creating a new job.
class CreateJobUseCase implements UseCase<Job, CreateJobParams> {
  final JobRepository repository;

  CreateJobUseCase(this.repository);

  @override
  Future<Either<Failure, Job>> call(CreateJobParams params) async {
    return await repository.createJob(
      audioFilePath: params.audioFilePath,
      text: params.text,
    );
  }
}

/// Parameters required for the [CreateJobUseCase].
class CreateJobParams extends Equatable {
  final String audioFilePath;
  final String? text;

  const CreateJobParams({required this.audioFilePath, this.text});

  @override
  List<Object?> get props => [audioFilePath, text];
}
