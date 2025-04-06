import 'package:dartz/dartz.dart';

import 'package:docjet_mobile/core/error/failures.dart';
import 'package:docjet_mobile/core/usecases/usecase.dart';
// import 'package:docjet_mobile/features/audio_recorder/domain/entities/audio_record.dart'; // No longer returning AudioRecord
import 'package:docjet_mobile/features/audio_recorder/domain/repositories/audio_recorder_repository.dart';

/// Use case for stopping the current audio recording.
class StopRecording implements UseCase<String, NoParams> {
  final AudioRecorderRepository repository;

  StopRecording(this.repository);

  /// Executes the use case.
  /// Returns the file path of the stopped recording, or a Failure.
  @override
  Future<Either<Failure, String>> call(NoParams params) async {
    // Directly return the result from the repository
    return await repository.stopRecording();
  }
}
