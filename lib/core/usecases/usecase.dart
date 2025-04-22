import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import 'package:docjet_mobile/core/error/failures.dart';

/// Abstract class for Use Cases.
/// [Type] is the return type of the use case.
/// [Params] is the input parameters type.
abstract class UseCase<Type, Params> {
  Future<Either<Failure, Type>> call(Params params);
}

/// Abstract class for Stream-based Use Cases.
/// [Type] is the return type of the use case (the stream element type).
/// [Params] is the input parameters type.
abstract class StreamUseCase<Type, Params> {
  Stream<Either<Failure, Type>> call(Params params);
}

/// Helper class to indicate that a UseCase does not require parameters.
class NoParams extends Equatable {
  @override
  List<Object?> get props => [];
}
