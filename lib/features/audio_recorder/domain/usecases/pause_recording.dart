import 'package:dartz/dartz.dart';

import 'package:docjet_mobile/core/error/failures.dart';
import 'package:docjet_mobile/core/usecases/usecase.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/repositories/audio_recorder_repository.dart';

/// Use case for pausing the current audio recording.
class PauseRecording implements UseCase<void, NoParams> {
  final AudioRecorderRepository repository;

  PauseRecording(this.repository);

  @override
  Future<Either<Failure, void>> call(NoParams params) async {
    return await repository.pauseRecording();
  }
}
