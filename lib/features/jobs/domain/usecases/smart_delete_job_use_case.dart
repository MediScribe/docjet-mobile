import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import 'package:docjet_mobile/core/error/failures.dart';
import 'package:docjet_mobile/core/usecases/usecase.dart';
import 'package:docjet_mobile/features/jobs/domain/repositories/job_repository.dart';

/// UseCase that handles "smart" deletion of jobs based on their server status
///
/// This use case attempts to determine if a job can be immediately purged (e.g.,
/// it's an orphan with no server counterpart or the server returns 404) or if it
/// should be marked for deletion and queued for server-side removal.
///
/// Returns:
/// - `Right(true)`: Job was immediately purged from local storage
/// - `Right(false)`: Job was marked for deletion but is still pending server-side removal
/// - `Left(Failure)`: An error occurred during the deletion process
class SmartDeleteJobUseCase implements UseCase<bool, SmartDeleteJobParams> {
  final JobRepository repository;

  SmartDeleteJobUseCase({required this.repository});

  @override
  Future<Either<Failure, bool>> call(SmartDeleteJobParams params) async {
    return await repository.smartDeleteJob(params.localId);
  }
}

/// Parameters for [SmartDeleteJobUseCase]
///
/// Contains the local ID of the job to be deleted.
class SmartDeleteJobParams extends Equatable {
  final String localId;

  const SmartDeleteJobParams({required this.localId});

  @override
  List<Object?> get props => [localId];
}
