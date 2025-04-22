import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:injectable/injectable.dart';

import 'package:docjet_mobile/core/utils/log_helpers.dart';
import 'package:docjet_mobile/core/error/failures.dart';
import 'package:docjet_mobile/features/jobs/domain/usecases/watch_job_by_id_use_case.dart';
import 'package:docjet_mobile/features/jobs/presentation/states/job_detail_state.dart';

@injectable
class JobDetailCubit extends Cubit<JobDetailState> {
  // Logger setup
  static final String _tag = logTag(JobDetailCubit);
  final Logger _logger = LoggerFactory.getLogger(JobDetailCubit);

  final WatchJobByIdUseCase _watchJobByIdUseCase;
  final String _jobId;
  StreamSubscription? _jobSubscription;

  JobDetailCubit({
    required WatchJobByIdUseCase watchJobByIdUseCase,
    @factoryParam required String jobId,
  }) : _watchJobByIdUseCase = watchJobByIdUseCase,
       _jobId = jobId,
       super(const JobDetailLoading()) {
    // Set logger level based on job ID (optional debug helper)
    // LoggerFactory.setLogLevel(JobDetailCubit, Level.debug);
    _watchJob();
  }

  void _watchJob() {
    _logger.d('$_tag [$_jobId] Subscribing to job stream');
    _jobSubscription?.cancel();
    _jobSubscription = _watchJobByIdUseCase
        .call(WatchJobParams(localId: _jobId)) // Corrected: Use WatchJobParams
        .listen(
          (eitherResult) {
            eitherResult.fold(
              (failure) {
                _logger.e(
                  '$_tag [$_jobId] Error watching job: ${failure.message}',
                  error: failure,
                  // stackTrace: StackTrace.current, // Optional: Add stack trace
                );
                emit(JobDetailError(message: failure.message));
              },
              (job) {
                if (job == null) {
                  _logger.i('$_tag [$_jobId] Job not found.');
                  emit(const JobDetailNotFound());
                } else {
                  _logger.d(
                    '$_tag [$_jobId] Job loaded/updated: ${job.localId}',
                  );
                  emit(JobDetailLoaded(job: job));
                }
              },
            );
          },
          onError: (error, stackTrace) {
            // Added stackTrace parameter
            _logger.e(
              '$_tag [$_jobId] Stream error: $error',
              error: error,
              stackTrace: stackTrace,
            );
            final errorMessage =
                (error is Failure) ? error.message : error.toString();
            emit(
              JobDetailError(
                message: 'An unexpected stream error occurred: $errorMessage',
              ),
            );
          },
          onDone: () {
            _logger.d('$_tag [$_jobId] Job stream closed.');
          },
        );
  }

  @override
  Future<void> close() {
    _logger.d('$_tag [$_jobId] Closing cubit and cancelling subscription.');
    _jobSubscription?.cancel();
    return super.close();
  }
}
