import 'package:dartz/dartz.dart';

import 'package:docjet_mobile/core/error/failures.dart';
import 'package:docjet_mobile/core/usecases/usecase.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/entities/audio_record.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/repositories/audio_recorder_repository.dart';

/// Use case for stopping the current audio recording.
class StopRecording implements UseCase<AudioRecord, NoParams> {
  final AudioRecorderRepository repository;

  StopRecording(this.repository);

  @override
  Future<Either<Failure, AudioRecord>> call(NoParams params) async {
    // Note: This simple version assumes we are NOT in an append operation.
    // A more complex implementation might check state or have a separate use case
    // for stopping an append operation (which would involve concatenation).
    return await repository.stopRecording();
  }
}
