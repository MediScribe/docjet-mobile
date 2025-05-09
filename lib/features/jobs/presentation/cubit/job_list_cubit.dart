import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:docjet_mobile/core/error/failures.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job.dart';
import 'package:bloc/bloc.dart';
import 'package:docjet_mobile/core/usecases/usecase.dart';
import 'package:docjet_mobile/core/utils/log_helpers.dart';
import 'package:docjet_mobile/features/jobs/domain/usecases/create_job_use_case.dart';
import 'package:docjet_mobile/features/jobs/domain/usecases/delete_job_use_case.dart';
import 'package:docjet_mobile/features/jobs/domain/usecases/watch_jobs_use_case.dart';
import 'package:docjet_mobile/features/jobs/presentation/mappers/job_view_model_mapper.dart';
import 'package:docjet_mobile/features/jobs/presentation/states/job_list_state.dart';
import 'package:docjet_mobile/features/jobs/presentation/models/job_view_model.dart';
import 'package:docjet_mobile/core/common/notifiers/app_notifier_service.dart';
import 'package:docjet_mobile/core/common/models/app_message.dart';

class JobListCubit extends Cubit<JobListState> {
  // Get logger instance for this class
  static final Logger _logger = LoggerFactory.getLogger(JobListCubit);
  // Create standard log tag
  static final String _tag = logTag(JobListCubit);

  final WatchJobsUseCase _watchJobsUseCase;
  final JobViewModelMapper _mapper;
  final CreateJobUseCase _createJobUseCase;
  final DeleteJobUseCase _deleteJobUseCase;
  final AppNotifierService? _appNotifierService;
  // Completer that signals the arrival of the first data/error event when (re)subscribing
  Completer<void>? _firstEventCompleter;
  StreamSubscription? _jobSubscription;

  JobListCubit({
    required WatchJobsUseCase watchJobsUseCase,
    required JobViewModelMapper mapper,
    required CreateJobUseCase createJobUseCase,
    required DeleteJobUseCase deleteJobUseCase,
    AppNotifierService? appNotifierService,
  }) : _watchJobsUseCase = watchJobsUseCase,
       _mapper = mapper,
       _createJobUseCase = createJobUseCase,
       _deleteJobUseCase = deleteJobUseCase,
       _appNotifierService = appNotifierService,
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
          // Surface error to the user via a transient banner
          _showErrorBanner('Failed to create job', failure);
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
      _showErrorBanner('Failed to create job', null, e);
      // Optionally emit a specific creation error state
    }
  }

  /// Refreshes the job list by re-subscribing to the data stream.
  Future<void> refreshJobs() async {
    // Emit loading state right before subscribing
    emit(const JobListLoading());
    _logger.d('$_tag: Subscribing to job stream...');

    // Cancel previous subscription
    if (_jobSubscription != null) {
      await _jobSubscription!.cancel();
    }

    // Initialise completer for first data/error event
    _firstEventCompleter = Completer<void>();

    _jobSubscription = _watchJobsUseCase
        .call(const NoParams())
        .listen(
          _handleJobEvent,
          onError:
              (Object error, StackTrace stack) =>
                  _handleStreamError(error, stack),
        );

    // Wait until the first event arrives before completing
    return _firstEventCompleter!.future;
  }

  // ----------------- Private Helpers -----------------

  void _handleJobEvent(Either<Failure, List<Job>> eitherResult) {
    eitherResult.fold(
      (failure) {
        _logger.e('$_tag: Error receiving job list: $failure');
        emit(JobListError(failure.toString()));
      },
      (jobs) {
        _logger.t('$_tag: Received ${jobs.length} jobs.');
        final viewModels = jobs.map(_mapper.toViewModel).toList();
        // Sort by displayDate, newest first
        viewModels.sort((a, b) => b.displayDate.compareTo(a.displayDate));
        emit(JobListLoaded(viewModels));
      },
    );

    if (_firstEventCompleter != null && !_firstEventCompleter!.isCompleted) {
      _firstEventCompleter!.complete();
    }
  }

  void _handleStreamError(Object error, StackTrace stack) {
    _logger.e('$_tag: Unhandled stream error', error: error, stackTrace: stack);
    emit(JobListError('JobListCubit stream error: ${error.toString()}'));

    if (_firstEventCompleter != null && !_firstEventCompleter!.isCompleted) {
      _firstEventCompleter!.complete();
    }
  }

  /// Deletes a job with **optimistic UI updates**.
  ///
  /// Behaviour:
  /// 1. If the current state is [JobListLoaded] the job is **optimistically**
  ///    removed from the list and a new [JobListLoaded] state is emitted so the
  ///    UI updates immediately.
  /// 2. The [DeleteJobUseCase] is executed.
  ///    * On **success** we only log – the authoritative list will be pushed
  ///      by the [_watchJobsUseCase] stream shortly afterwards.
  ///    * On **failure** we surface a user-facing banner via
  ///      [AppNotifierService.show] **and** roll-back by re-emitting the
  ///      previously cached list so the UI stays consistent. No `JobListError`
  ///      state is emitted anymore.
  /// 3. If the Cubit isn't in a loaded state we delegate directly to the use
  ///    case and rely on the watcher stream.
  Future<void> deleteJob(String localId) async {
    _logger.i('$_tag: Attempting to delete job with ID: $localId');

    // Optimistically remove the job from the current list (if loaded)
    List<JobViewModel>? previousJobs;
    if (state is JobListLoaded) {
      previousJobs = List<JobViewModel>.from((state as JobListLoaded).jobs);
      final updatedJobs =
          previousJobs.where((j) => j.localId != localId).toList();
      emit(JobListLoaded(updatedJobs));
    }

    try {
      final result = await _deleteJobUseCase(DeleteJobParams(localId: localId));
      result.fold((failure) {
        _logger.e('$_tag: Failed to delete job: $failure');
        _showErrorBanner('Failed to delete job', failure);
        // Roll-back the optimistic update so the UI reflects actual data
        if (previousJobs != null) {
          emit(JobListLoaded(previousJobs));
        }
      }, (_) => _logger.i('$_tag: Successfully deleted job with ID: $localId'));
    } catch (e, st) {
      _logger.e(
        '$_tag: Exception while deleting job: $e',
        error: e,
        stackTrace: st,
      );
      _showErrorBanner('Failed to delete job', null, e);
      if (previousJobs != null) {
        emit(JobListLoaded(previousJobs));
      }
    }
  }

  @override
  Future<void> close() {
    _logger.d('$_tag: Closing and cancelling subscription');
    _jobSubscription?.cancel();
    return super.close();
  }

  // Centralised error banner helper to keep messaging consistent.
  void _showErrorBanner(String baseMessage, [Failure? failure, Object? error]) {
    final detail =
        failure?.message.isNotEmpty == true
            ? failure!.message
            : error?.toString() ?? '';

    final message = detail.isNotEmpty ? '$baseMessage: $detail' : baseMessage;

    _appNotifierService?.show(message: message, type: MessageType.error);
  }
}
