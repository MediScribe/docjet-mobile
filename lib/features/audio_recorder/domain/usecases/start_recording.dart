import 'package:dartz/dartz.dart';

import 'package:docjet_mobile/core/error/failures.dart';
import 'package:docjet_mobile/core/usecases/usecase.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/repositories/audio_recorder_repository.dart';

/// Use case for starting a new audio recording.
class StartRecording implements UseCase<String, NoParams> {
  final AudioRecorderRepository repository;

  StartRecording(this.repository);

  @override
  Future<Either<Failure, String>> call(NoParams params) async {
    return await repository.startRecording();
  }
}
