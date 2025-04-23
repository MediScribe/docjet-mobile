import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:docjet_mobile/core/utils/log_helpers.dart';
import 'package:docjet_mobile/features/jobs/domain/usecases/watch_job_by_id_use_case.dart';
import 'package:docjet_mobile/features/jobs/presentation/states/job_detail_state.dart';

class JobDetailCubit extends Cubit<JobDetailState> {
  // Get logger instance for this class
  static final Logger _logger = LoggerFactory.getLogger(JobDetailCubit);
  // Create standard log tag
  static final String _tag = logTag(JobDetailCubit);

  final WatchJobByIdUseCase _watchJobByIdUseCase;
  final String _jobId;
  StreamSubscription? _jobSubscription;

  JobDetailCubit({
    required WatchJobByIdUseCase watchJobByIdUseCase,
    required String jobId,
  }) : _watchJobByIdUseCase = watchJobByIdUseCase,
       _jobId = jobId,
       super(const JobDetailLoading()) {
    // Start watching job immediately
    _logger.d('$_tag: Initializing for job $_jobId');
    _watchJob();
  }

  void _watchJob() {
    // Emit loading state right before subscribing
    emit(const JobDetailLoading());
    _logger.d('$_tag: Starting to watch job $_jobId');

    _jobSubscription?.cancel(); // Ensure no lingering subscription

    final params = WatchJobParams(localId: _jobId);
    _jobSubscription = _watchJobByIdUseCase
        .call(params)
        .listen(
          (eitherResult) {
            eitherResult.fold(
              (failure) {
                _logger.e(
                  '$_tag: Error receiving job $_jobId: ${failure.message}',
                );
                emit(JobDetailError(message: failure.message));
              },
              (job) {
                if (job != null) {
                  _logger.t('$_tag: Received job update for $_jobId');
                  emit(JobDetailLoaded(job: job));
                } else {
                  _logger.w('$_tag: Job $_jobId not found');
                  emit(const JobDetailNotFound());
                }
              },
            );
          },
          onError: (error) {
            // Handle potential stream errors if the Either doesn't catch them
            _logger.e('$_tag: Unhandled stream error for job $_jobId: $error');
            emit(
              JobDetailError(
                message: 'JobDetailCubit stream error: ${error.toString()}',
              ),
            );
          },
        );
  }

  @override
  Future<void> close() {
    _logger.d('$_tag: Closing and cancelling subscription for job $_jobId');
    _jobSubscription?.cancel();
    return super.close();
  }
}
