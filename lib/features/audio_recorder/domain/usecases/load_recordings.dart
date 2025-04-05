import 'package:dartz/dartz.dart';
import 'package:docjet_mobile/core/error/failures.dart';
import 'package:docjet_mobile/core/usecases/usecase.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/entities/audio_record.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/repositories/audio_recorder_repository.dart';

class LoadRecordings implements UseCase<List<AudioRecord>, NoParams> {
  final AudioRecorderRepository repository;

  LoadRecordings(this.repository);

  @override
  Future<Either<Failure, List<AudioRecord>>> call(NoParams params) async {
    return await repository.loadRecordings();
  }
}
