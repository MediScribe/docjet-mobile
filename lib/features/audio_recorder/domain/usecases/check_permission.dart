import 'package:dartz/dartz.dart';

import 'package:docjet_mobile/core/error/failures.dart';
import 'package:docjet_mobile/core/usecases/usecase.dart'; // Assuming a base UseCase structure
import 'package:docjet_mobile/features/audio_recorder/domain/repositories/audio_recorder_repository.dart';

/// Use case for checking microphone permission.
class CheckPermission implements UseCase<bool, NoParams> {
  final AudioRecorderRepository repository;

  CheckPermission(this.repository);

  @override
  Future<Either<Failure, bool>> call(NoParams params) async {
    // First check current status
    final checkResult = await repository.checkPermission();

    return checkResult.fold(
      (failure) {
        return Left(failure);
      },
      (hasPermission) async {
        if (hasPermission) {
          return Right(true);
        } else {
          final requestResult = await repository.requestPermission();
          return requestResult;
        }
      },
    );
  }
}
