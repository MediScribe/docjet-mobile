import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:docjet_mobile/core/usecases/usecase.dart';
import 'package:docjet_mobile/core/utils/log_helpers.dart';
import 'package:docjet_mobile/features/jobs/domain/usecases/create_job_use_case.dart';
import 'package:docjet_mobile/features/jobs/domain/usecases/delete_job_use_case.dart';
import 'package:docjet_mobile/features/jobs/domain/usecases/watch_jobs_use_case.dart';
import 'package:docjet_mobile/features/jobs/presentation/mappers/job_view_model_mapper.dart';
import 'package:docjet_mobile/features/jobs/presentation/states/job_list_state.dart';

class JobListCubit extends Cubit<JobListState> {
  // Get logger instance for this class
  static final Logger _logger = LoggerFactory.getLogger(JobListCubit);
  // Create standard log tag
  static final String _tag = logTag(JobListCubit);

  final WatchJobsUseCase _watchJobsUseCase;
  final JobViewModelMapper _mapper;
  final CreateJobUseCase _createJobUseCase;
  final DeleteJobUseCase _deleteJobUseCase;
  StreamSubscription? _jobSubscription;

  JobListCubit({
    required WatchJobsUseCase watchJobsUseCase,
    required JobViewModelMapper mapper,
    required CreateJobUseCase createJobUseCase,
    required DeleteJobUseCase deleteJobUseCase,
  }) : _watchJobsUseCase = watchJobsUseCase,
       _mapper = mapper,
       _createJobUseCase = createJobUseCase,
       _deleteJobUseCase = deleteJobUseCase,
       super(const JobListInitial()) {
    _logger.d('$_tag: Initializing...');
    // Start loading immediately and subscribe to the stream
    refreshJobs();
  }

  /// Creates a new job using the injected use case.
  Future<void> createJob(CreateJobParams params) async {
    _logger.d('$_tag: Attempting to create job with params: $params');
    // Note: We might want loading/error states specific to creation
    // For now, just call the use case and let the list update via the stream.
    try {
      final result = await _createJobUseCase(params);
      result.fold(
        (failure) {
          _logger.e('$_tag: Failed to create job: $failure');
          // Optionally emit a specific creation error state
        },
        (success) {
          _logger.i('$_tag: Successfully initiated job creation.');
          // List will update via the stream watcher
        },
      );
    } catch (e, st) {
      _logger.e(
        '$_tag: Exception during job creation: $e',
        error: e,
        stackTrace: st,
      );
      // Optionally emit a specific creation error state
    }
  }

  /// Refreshes the job list by re-subscribing to the data stream.
  Future<void> refreshJobs() async {
    // Emit loading state right before subscribing
    emit(const JobListLoading());
    _logger.d('$_tag: Subscribing to job stream...');

    // Cancel previous subscription
    _jobSubscription?.cancel();

    // Completer that completes on first data or error event
    final firstEventCompleter = Completer<void>();

    _jobSubscription = _watchJobsUseCase
        .call(NoParams())
        .listen(
          (eitherResult) {
            eitherResult.fold(
              (failure) {
                _logger.e('$_tag: Error receiving job list: $failure');
                emit(JobListError(failure.toString()));
              },
              (jobs) {
                _logger.t('$_tag: Received ${jobs.length} jobs.');
                final viewModels = jobs.map(_mapper.toViewModel).toList();
                // Sort by displayDate, newest first
                viewModels.sort(
                  (a, b) => b.displayDate.compareTo(a.displayDate),
                );
                emit(JobListLoaded(viewModels));
              },
            );
            if (!firstEventCompleter.isCompleted) {
              firstEventCompleter.complete();
            }
          },
          onError: (error) {
            // Handle potential stream errors if the Either doesn't catch them
            _logger.e('$_tag: Unhandled stream error: $error');
            emit(
              JobListError('JobListCubit stream error: ${error.toString()}'),
            );
            if (!firstEventCompleter.isCompleted) {
              firstEventCompleter.complete();
            }
          },
        );

    // Wait until the first event arrives before completing
    return firstEventCompleter.future;
  }

  /// Deletes a job using the DeleteJobUseCase.
  ///
  /// This method does not emit new job list states as the UI will be updated
  /// automatically via the WatchJobsUseCase stream when the job is deleted.
  /// However, it does emit error states if the deletion fails.
  Future<void> deleteJob(String localId) async {
    _logger.i('$_tag: Attempting to delete job with ID: $localId');
    try {
      final result = await _deleteJobUseCase(DeleteJobParams(localId: localId));
      result.fold((failure) {
        _logger.e('$_tag: Failed to delete job: $failure');
        emit(JobListError('Failed to delete job: ${failure.toString()}'));
      }, (_) => _logger.i('$_tag: Successfully deleted job with ID: $localId'));
    } catch (e, st) {
      _logger.e(
        '$_tag: Exception while deleting job: $e',
        error: e,
        stackTrace: st,
      );
      emit(JobListError('Unexpected error deleting job: ${e.toString()}'));
    }
    // UI relies on WatchJobsUseCase stream for updates after successful deletion
  }

  @override
  Future<void> close() {
    _logger.d('$_tag: Closing and cancelling subscription');
    _jobSubscription?.cancel();
    return super.close();
  }
}
