import 'package:dartz/dartz.dart';
import 'package:docjet_mobile/core/error/failures.dart';
import 'package:docjet_mobile/core/usecases/usecase.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/repositories/audio_recorder_repository.dart';

// UseCase definition: Takes NoParams, returns Either<Failure, bool>
class RequestPermission extends UseCase<bool, NoParams> {
  final AudioRecorderRepository repository;

  RequestPermission(this.repository);

  @override
  Future<Either<Failure, bool>> call(NoParams params) async {
    return await repository.requestPermission();
  }
}

// NoParams remains the standard empty parameter class
// class NoParams extends Equatable { // Already defined in core/usecases/usecase.dart
//   @override
//   List<Object?> get props => [];
// }
