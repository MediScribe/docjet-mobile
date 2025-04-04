import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import 'package:docjet_mobile/core/error/failures.dart';
import 'package:docjet_mobile/core/usecases/usecase.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/repositories/audio_recorder_repository.dart';

/// Use case for deleting a specific audio recording.
class DeleteRecording implements UseCase<void, DeleteRecordingParams> {
  final AudioRecorderRepository repository;

  DeleteRecording(this.repository);

  @override
  Future<Either<Failure, void>> call(DeleteRecordingParams params) async {
    return await repository.deleteRecording(params.filePath);
  }
}

class DeleteRecordingParams extends Equatable {
  final String filePath;

  const DeleteRecordingParams({required this.filePath});

  @override
  List<Object> get props => [filePath];
}
