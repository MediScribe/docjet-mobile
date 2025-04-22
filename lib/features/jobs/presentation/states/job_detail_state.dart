import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:docjet_mobile/features/jobs/domain/entities/job.dart';

part 'job_detail_state.freezed.dart';

@freezed
abstract class JobDetailState with _$JobDetailState {
  const factory JobDetailState.loading() = JobDetailLoading;
  const factory JobDetailState.loaded({required Job job}) = JobDetailLoaded;
  const factory JobDetailState.notFound() = JobDetailNotFound;
  const factory JobDetailState.error({required String message}) =
      JobDetailError;
}
