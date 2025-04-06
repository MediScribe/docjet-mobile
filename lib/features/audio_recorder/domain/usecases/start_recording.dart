import 'package:dartz/dartz.dart';

import 'package:docjet_mobile/core/error/failures.dart';
import 'package:docjet_mobile/core/usecases/usecase.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/repositories/audio_recorder_repository.dart';

/// Use case for starting a new audio recording.
class StartRecording implements UseCase<String, NoParams> {
  final AudioRecorderRepository repository;

  StartRecording(this.repository);

  /// Executes the use case.
  /// Returns [Right(String)] with the recording path on success, otherwise [Left(Failure)].
  @override
  Future<Either<Failure, String>> call(NoParams params) async {
    // Directly return the result from the repository
    return await repository.startRecording();
  }
}
