import 'package:dartz/dartz.dart';

import 'package:docjet_mobile/core/error/failures.dart';
import 'package:docjet_mobile/core/usecases/usecase.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/repositories/audio_recorder_repository.dart';

/// Use case for resuming a paused audio recording.
class ResumeRecording implements UseCase<void, NoParams> {
  final AudioRecorderRepository repository;

  ResumeRecording(this.repository);

  @override
  Future<Either<Failure, void>> call(NoParams params) async {
    return await repository.resumeRecording();
  }
}
