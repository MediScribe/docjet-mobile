import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:docjet_mobile/core/usecases/usecase.dart'; // For NoParams
import 'package:docjet_mobile/core/utils/log_helpers.dart';
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
  StreamSubscription? _jobSubscription;

  JobListCubit({
    required WatchJobsUseCase watchJobsUseCase,
    required JobViewModelMapper mapper,
  }) : _watchJobsUseCase = watchJobsUseCase,
       _mapper = mapper,
       super(const JobListInitial()) {
    _logger.d('$_tag: Initializing...');
    // Start loading immediately and subscribe to the stream
    _subscribeToJobStream();
  }

  /// Loads and starts watching the job list.
  // void loadJobs() {
  //   // Cancel previous subscription if exists
  //   _jobSubscription?.cancel();
  //
  //   emit(state.copyWith(isLoading: true, clearError: true));
  //
  //   _jobSubscription = _watchJobsUseCase
  //       .call(NoParams())
  //       .listen(
  //         (eitherResult) {
  //           eitherResult.fold(
  //             (failure) {
  //               emit(
  //                 state.copyWith(
  //                   isLoading: false,
  //                   error:
  //                       failure
  //                           .toString(), // Use toString() for generic failure message
  //                 ),
  //               );
  //             },
  //             (jobs) {
  //               // Use a local variable for mapping to avoid potential race condition with state access?
  //               // Though, bloc is single-threaded, so maybe not necessary. Being explicit.
  //               final viewModels = jobs.map(_mapper.toViewModel).toList();
  //               emit(state.copyWith(isLoading: false, jobs: viewModels));
  //             },
  //           );
  //         },
  //         onError: (error) {
  //           // Handle potential stream errors if the Either doesn't catch them
  //           // This might indicate a problem in the use case or repository layer
  //           emit(
  //             state.copyWith(
  //               isLoading: false,
  //               error: 'JobListCubit stream error: ${error.toString()}',
  //             ),
  //           );
  //         },
  //       );
  // }

  void _subscribeToJobStream() {
    // Emit loading state right before subscribing
    emit(const JobListLoading());
    _logger.d('$_tag: Subscribing to job stream...');

    _jobSubscription?.cancel(); // Ensure no lingering subscription
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
                emit(JobListLoaded(viewModels));
              },
            );
          },
          onError: (error) {
            // Handle potential stream errors if the Either doesn't catch them
            _logger.e('$_tag: Unhandled stream error: $error');
            emit(
              JobListError('JobListCubit stream error: ${error.toString()}'),
            );
          },
        );
  }

  @override
  Future<void> close() {
    _logger.d('$_tag: Closing and cancelling subscription');
    _jobSubscription?.cancel();
    return super.close();
  }
}
