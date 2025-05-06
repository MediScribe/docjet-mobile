import 'dart:async';

import 'package:dartz/dartz.dart'; // Import dartz
import 'package:docjet_mobile/core/auth/auth_session_provider.dart';
import 'package:docjet_mobile/core/auth/events/auth_event_bus.dart'; // Import AuthEventBus
import 'package:docjet_mobile/core/auth/events/auth_events.dart'; // Import AuthEvent enum
import 'package:docjet_mobile/core/error/failures.dart'; // Import Failure
import 'package:docjet_mobile/core/utils/log_helpers.dart'; // Import Logger
import 'package:docjet_mobile/features/jobs/data/datasources/job_local_data_source.dart'; // Import LocalDataSource directly
import 'package:docjet_mobile/features/jobs/domain/entities/job.dart';
import 'package:docjet_mobile/features/jobs/domain/repositories/job_repository.dart';
import 'package:docjet_mobile/features/jobs/data/models/job_update_data.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job_update_details.dart';
import 'package:docjet_mobile/features/jobs/data/services/job_deleter_service.dart';
import 'package:docjet_mobile/features/jobs/data/services/job_reader_service.dart';
import 'package:docjet_mobile/features/jobs/data/services/job_sync_orchestrator_service.dart';
import 'package:docjet_mobile/features/jobs/data/services/job_writer_service.dart';

/// Main implementation of [JobRepository] that orchestrates operations
/// by delegating to specialized service classes.
class JobRepositoryImpl implements JobRepository {
  final JobReaderService _readerService;
  final JobWriterService _writerService;
  final JobDeleterService _deleterService;
  final JobSyncOrchestratorService _orchestratorService;
  final AuthSessionProvider _authSessionProvider;
  final AuthEventBus
  _authEventBus; // Auth event bus for listening to auth events
  final JobLocalDataSource
  _localDataSource; // Direct reference to local data source
  final Logger _logger = LoggerFactory.getLogger(JobRepositoryImpl);
  static final String _tag = logTag(JobRepositoryImpl);

  // Subscription to auth events
  StreamSubscription<AuthEvent>? _authEventSubscription;

  /// Creates an instance of [JobRepositoryImpl].
  ///
  /// Requires instances of all the specialized job services, an AuthSessionProvider
  /// to provide the authenticated user's context, and an AuthEventBus to listen
  /// for authentication events.
  JobRepositoryImpl({
    required JobReaderService readerService,
    required JobWriterService writerService,
    required JobDeleterService deleterService,
    required JobSyncOrchestratorService orchestratorService,
    required AuthSessionProvider authSessionProvider,
    required AuthEventBus authEventBus,
    required JobLocalDataSource localDataSource, // Fixed line break
  }) : _readerService = readerService,
       _writerService = writerService,
       _deleterService = deleterService,
       _orchestratorService = orchestratorService,
       _authSessionProvider = authSessionProvider,
       _authEventBus = authEventBus,
       _localDataSource = localDataSource {
    _logger.i('JobRepositoryImpl initialized.');

    // Subscribe to auth events
    _subscribeToAuthEvents();
  }

  /// Subscribes to authentication events to react to login/logout
  void _subscribeToAuthEvents() {
    _logger.d('Subscribing to auth events.');
    _authEventSubscription = _authEventBus.stream.listen((event) {
      if (event == AuthEvent.loggedOut) {
        _handleLogout();
      }
    });
  }

  /// Handles logout event by clearing user-specific data
  Future<void> _handleLogout() async {
    _logger.i('$_tag Handling logout event. Clearing user data.');
    try {
      await _localDataSource.clearUserData();
      _logger.i('$_tag Successfully cleared user data on logout.');
    } catch (e) {
      _logger.e('$_tag Error clearing user data on logout: $e');
    }
  }

  /// Disposes resources used by this repository
  void dispose() {
    _authEventSubscription?.cancel();
    _logger.d('$_tag Disposed auth event subscription.');
  }

  // --- FETCHING OPERATIONS ---

  @override
  Future<Either<Failure, List<Job>>> getJobs() {
    _logger.d('$_tag Delegating getJobs to JobReaderService...');
    return _readerService.getJobs();
  }

  @override
  Future<Either<Failure, Job>> getJobById(String localId) {
    _logger.d('$_tag Delegating getJobById($localId) to JobReaderService...');
    return _readerService.getJobById(localId);
  }

  // --- WRITE OPERATIONS ---

  @override
  Future<Either<Failure, Job>> createJob({
    required String audioFilePath,
    String? text,
  }) async {
    _logger.d(
      '$_tag createJob called with audioFilePath: $audioFilePath, text: $text',
    );

    // --- Authentication Check ---
    if (!await _authSessionProvider.isAuthenticated()) {
      _logger.w('$_tag User not authenticated. Cannot create job.');
      return Left(AuthFailure());
    }

    // No longer call getCurrentUserId here. The writer service will handle that.
    _logger.d('$_tag User authenticated, proceeding to delegate job creation.');

    // Delegate to writer service - NO userId passed from here
    final Either<Failure, Job> createJobResult = await _writerService.createJob(
      audioFilePath: audioFilePath,
      text: text,
    );

    // After successful local creation, trigger immediate sync (fire-and-forget)
    createJobResult.fold(
      (failure) {
        // If creation failed, do nothing extra, just return the failure
        _logger.w(
          '$_tag Job creation failed with $failure. No immediate sync will be triggered.',
        );
      },
      (job) {
        // If creation succeeded, trigger sync
        _logger.i(
          '$_tag Job ${job.localId} created locally. Triggering immediate sync attempt.',
        );
        _triggerImmediateSync(job);
      },
    );

    return createJobResult; // Return the original result of job creation
  }

  /// Triggers an immediate sync attempt for a newly created job.
  /// This is a fire-and-forget operation that doesn't affect the result of createJob.
  void _triggerImmediateSync(Job job) {
    unawaited(
      _orchestratorService
          .syncPendingJobs()
          .then(
            (syncResult) => syncResult.fold(
              (syncFailure) => _logger.w(
                '$_tag Immediate sync for ${job.localId} failed: $syncFailure (does not affect createJob result)',
              ),
              (_) => _logger.i(
                '$_tag Immediate sync for ${job.localId} completed/skipped (does not affect createJob result)',
              ),
            ),
          )
          .catchError((error, stackTrace) {
            // Catch any unexpected error from the Future itself
            _logger.e(
              '$_tag Unexpected error in syncPendingJobs for ${job.localId} (does not affect createJob result)',
              error: error,
              stackTrace: stackTrace,
            );
          }),
    );
  }

  @override
  Future<Either<Failure, Job>> updateJob({
    required String localId,
    required JobUpdateDetails updates,
  }) {
    _logger.d(
      '$_tag Delegating updateJob(localId: $localId, updates: ...) to JobWriterService...',
    );
    final updateData = JobUpdateData(text: updates.text);
    return _writerService.updateJob(localId: localId, updates: updateData);
  }

  // --- DELETE OPERATIONS ---

  @override
  Future<Either<Failure, Unit>> deleteJob(String localId) {
    _logger.d('$_tag Delegating deleteJob($localId) to JobDeleterService...');
    return _deleterService.deleteJob(localId);
  }

  // --- SYNC OPERATIONS ---

  @override
  Future<Either<Failure, Unit>> syncPendingJobs() {
    _logger.d('$_tag Delegating syncPendingJobs to JobSyncOrchestratorService');
    return _orchestratorService.syncPendingJobs();
  }

  @override
  Future<Either<Failure, Unit>> reconcileJobsWithServer() async {
    _logger.d('$_tag Reconciling jobs with server');

    try {
      final result = await _readerService.getJobs();
      return result.fold(
        (failure) {
          _logger.w('$_tag Failed to reconcile jobs with server: $failure');
          return Left(failure);
        },
        (_) {
          _logger.i('$_tag Successfully reconciled jobs with server');
          return const Right(unit);
        },
      );
    } catch (e, stackTrace) {
      _logger.e(
        '$_tag Exception during jobs reconciliation',
        error: e,
        stackTrace: stackTrace,
      );
      return Left(
        UnknownFailure('Unexpected error during jobs reconciliation'),
      );
    }
  }

  @override
  Future<Either<Failure, Unit>> resetFailedJob(String localId) {
    _logger.d(
      '$_tag Delegating resetFailedJob for localId: $localId to JobSyncOrchestratorService',
    );
    // Delegate directly to the orchestrator service's method
    return _orchestratorService.resetFailedJob(localId: localId);
  }

  // --- Stream Operations ---

  @override
  Stream<Either<Failure, List<Job>>> watchJobs() {
    _logger.d('$_tag watchJobs called');
    return _readerService.watchJobs();
  }

  @override
  Stream<Either<Failure, Job?>> watchJobById(String localId) {
    _logger.d('$_tag watchJobById called for id: $localId');
    return _readerService.watchJobById(localId);
  }
}
