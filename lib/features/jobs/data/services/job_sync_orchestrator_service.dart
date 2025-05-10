import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:docjet_mobile/core/auth/events/auth_event_bus.dart';
import 'package:docjet_mobile/core/auth/events/auth_events.dart';
import 'package:docjet_mobile/core/error/exceptions.dart';
import 'package:docjet_mobile/core/error/failures.dart';
import 'package:docjet_mobile/core/interfaces/network_info.dart';
import 'package:docjet_mobile/core/utils/log_helpers.dart';
import 'package:docjet_mobile/features/jobs/data/config/job_sync_config.dart';
import 'package:docjet_mobile/features/jobs/data/datasources/job_local_data_source.dart';
import 'package:docjet_mobile/features/jobs/data/services/job_sync_processor_service.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/sync_status.dart';
import 'package:mutex/mutex.dart';

/// Service class for orchestrating job synchronization with remote server
class JobSyncOrchestratorService {
  final JobLocalDataSource _localDataSource;
  final NetworkInfo _networkInfo;
  final JobSyncProcessorService _processorService; // Inject processor
  final AuthEventBus _authEventBus; // Add auth event bus
  final Logger _logger = LoggerFactory.getLogger(
    JobSyncOrchestratorService,
  ); // Use LoggerFactory
  // Uses a re-entrant mutex from package:mutex to prevent concurrent sync runs.
  // Re-entrant means the same thread/zone can acquire the lock multiple times without deadlocking.
  final Mutex _syncMutex = Mutex(); // Add mutex for sync control

  // Flag to track auth-based offline state
  bool _isOfflineFromAuth = false;
  bool _isLoggedOut = false;

  // Getter for the logout status
  bool get isLogoutInProgress => _isLoggedOut;

  // Stream subscription for auth events
  StreamSubscription<AuthEvent>? _authEventSubscription;

  JobSyncOrchestratorService({
    required JobLocalDataSource localDataSource,
    required NetworkInfo networkInfo,
    required JobSyncProcessorService processorService,
    required AuthEventBus authEventBus,
  }) : _localDataSource = localDataSource,
       _networkInfo = networkInfo,
       _processorService = processorService,
       _authEventBus = authEventBus {
    _subscribeToAuthEvents();
    _logger.i(
      'JobSyncOrchestratorService initialized with auth event subscription.',
    );
  }

  /// Subscribes to the AuthEventBus to receive authentication-related events
  void _subscribeToAuthEvents() {
    _authEventSubscription = _authEventBus.stream.listen((event) {
      _logger.i('Received auth event: $event');

      switch (event) {
        case AuthEvent.offlineDetected:
          _handleOfflineDetected();
          break;
        case AuthEvent.onlineRestored:
          _handleOnlineRestored();
          break;
        case AuthEvent.loggedOut:
          _handleLoggedOut();
          break;
        case AuthEvent.loggedIn:
          _handleLoggedIn();
          break;
      }
    });
  }

  /// Handles transition to offline state
  void _handleOfflineDetected() {
    _logger.i('Received offlineDetected event; pausing sync operations');
    _isOfflineFromAuth = true;
  }

  /// Handles restoration of online connectivity
  void _handleOnlineRestored() {
    _logger.i('Received onlineRestored event; resuming sync operations');
    _isOfflineFromAuth = false;

    // Trigger an immediate sync to push any pending changes
    _triggerImmediateSync();
  }

  /// Handles user logout event
  void _handleLoggedOut() {
    _logger.i('Received loggedOut event; stopping sync operations');
    _isLoggedOut = true;
  }

  /// Handles user login event
  void _handleLoggedIn() {
    _logger.i('Received loggedIn event; enabling sync operations');
    _isLoggedOut = false;
  }

  /// Triggers an immediate sync operation
  Future<void> _triggerImmediateSync() async {
    _logger.i('Triggering immediate sync after connectivity change');
    try {
      await syncPendingJobs();
    } catch (e) {
      _logger.e('Error during immediate sync: $e');
    }
  }

  Future<Either<Failure, Unit>> syncPendingJobs() async {
    _logger.i('Attempting to start syncPendingJobs...');

    // Skip sync if we're in offline mode from auth events
    if (_isOfflineFromAuth) {
      _logger.i('Skipping sync due to auth-detected offline state.');
      return const Right(unit);
    }

    // Skip sync if user is logged out
    if (_isLoggedOut) {
      _logger.i('Skipping sync because user is logged out.');
      return const Right(unit);
    }

    // Prevent concurrent execution
    if (_syncMutex.isLocked) {
      _logger.i('Sync already in progress. Skipping this run.');
      return const Right(unit);
    }

    await _syncMutex.acquire();
    _logger.i('Acquired sync lock. Starting sync process.');

    try {
      if (!await _networkInfo.isConnected) {
        _logger.w('Network offline, skipping sync.');
        // Return success (Right) because skipping due to offline is expected
        return const Right(unit);
      }

      List<Job> pendingJobs = [];
      List<Job> deletionJobs = [];
      List<Job> retryJobs = [];

      // Inner try-catch specifically for data source fetching
      try {
        _logger.d('Fetching jobs pending sync...');
        pendingJobs = await _localDataSource.getJobsByStatus(
          SyncStatus.pending,
        );
        _logger.d('Found ${pendingJobs.length} jobs pending create/update.');

        _logger.d('Fetching jobs pending deletion...');
        deletionJobs = await _localDataSource.getJobsByStatus(
          SyncStatus.pendingDeletion,
        );
        _logger.d('Found ${deletionJobs.length} jobs pending deletion.');

        _logger.d('Fetching jobs eligible for retry...');
        retryJobs = await _localDataSource.getJobsToRetry(
          maxRetryAttempts,
          retryBackoffBase,
        );
        _logger.d('Found ${retryJobs.length} jobs eligible for retry.');
      } on CacheException catch (e) {
        // Log the fetch error, but allow the orchestrator to continue
        // It might still be able to process other job types fetched successfully
        _logger.e('Cache error during job fetching phase: $e');
        // Do NOT return Left(...) here. Allow processing of any successfully fetched jobs.
      }

      // Log the retry backoff schedule for monitoring purposes
      if (retryJobs.isNotEmpty) {
        _logger.d(
          'Found ${retryJobs.length} jobs to retry (backoff logic handled by LocalDataSource).',
        );
      }

      // ** Combine pending and retry jobs for syncSingleJob processing **
      final jobsToSync = [...pendingJobs, ...retryJobs];
      _logger.d(
        'Total jobs to attempt sync (pending + retry): ${jobsToSync.length}',
      );

      // Process creates/updates/retries using the processor
      if (jobsToSync.isNotEmpty) {
        _logger.i('Starting synchronization of ${jobsToSync.length} jobs');
        // Only log each job at debug level to reduce noise at info level
        int processedCount = 0;
        for (final job in jobsToSync) {
          _logger.d(
            'Orchestrating sync for job (localId: ${job.localId}, status: ${job.syncStatus})...',
          );
          // Call the processor service
          await _processorService.processJobSync(job);
          processedCount++;

          // Check if we should abort processing due to offline/logout
          if (_isOfflineFromAuth) {
            _logger.w(
              'Aborting in-flight sync due to offline event after processing $processedCount/${jobsToSync.length} jobs',
            );
            break;
          }
          if (_isLoggedOut) {
            _logger.w(
              'Aborting in-flight sync due to logout event after processing $processedCount/${jobsToSync.length} jobs',
            );
            break;
          }
        }
        _logger.i(
          'Completed synchronization of $processedCount/${jobsToSync.length} jobs',
        );
      }

      // Process deletions using the processor
      if (deletionJobs.isNotEmpty) {
        _logger.i('Starting deletion of ${deletionJobs.length} jobs');
        // Only log each job at debug level to reduce noise at info level
        int processedCount = 0;
        for (final job in deletionJobs) {
          _logger.d(
            'Orchestrating deletion for job (localId: ${job.localId}, serverId: ${job.serverId})...',
          );
          // Call the processor service
          await _processorService.processJobDeletion(job);
          processedCount++;

          // Check if we should abort processing due to offline/logout
          if (_isOfflineFromAuth) {
            _logger.w(
              'Aborting in-flight deletion due to offline event after processing $processedCount/${deletionJobs.length} jobs',
            );
            break;
          }
          if (_isLoggedOut) {
            _logger.w(
              'Aborting in-flight deletion due to logout event after processing $processedCount/${deletionJobs.length} jobs',
            );
            break;
          }
        }
        _logger.i(
          'Completed deletion of $processedCount/${deletionJobs.length} jobs',
        );
      }

      _logger.i('syncPendingJobs completed successfully inside lock.');
      return const Right(unit);
    } on ServerException catch (e) {
      // This might still happen if network check fails, but less likely for job-specific errors now
      _logger.e('Server error during sync orchestration: $e');
      return Left(ServerFailure(message: e.message ?? 'Unknown server error'));
    } catch (e) {
      _logger.e('Unexpected error during sync orchestration: $e');
      return Left(ServerFailure(message: 'Unexpected error during sync: $e'));
    } finally {
      _syncMutex.release();
      _logger.i('Released sync lock.');
    }
  }

  /// Resets a job stuck in the [SyncStatus.failed] state back to [SyncStatus.pending].
  ///
  /// If the job is found and is in the failed state, its status is updated to pending,
  /// the retry count is reset to 0, and the last sync attempt timestamp is cleared.
  /// If the job is not found or not in the failed state, it does nothing.
  /// Returns [Right(unit)] on success (including cases where no action was needed)
  /// or [Left(Failure)] if a cache error occurs during fetching or saving.
  Future<Either<Failure, Unit>> resetFailedJob({
    required String localId,
  }) async {
    _logger.i('Attempting to reset job with localId: $localId');
    try {
      Job job;
      try {
        job = await _localDataSource.getJobById(localId);
        _logger.d('Found job: ${job.localId}, syncStatus: ${job.syncStatus}');
      } on CacheException catch (e) {
        // If the job is not found, it's not an error for the reset operation.
        // Log it and return success (Right(unit)).
        _logger.w('Job with localId $localId not found in cache: $e');
        return const Right(unit);
      }

      // Only proceed if the job is actually in the failed state
      if (job.syncStatus == SyncStatus.failed) {
        _logger.i(
          'Job ${job.localId} is in failed state. Proceeding with reset.',
        );
        final updatedJob = job.copyWith(
          syncStatus: SyncStatus.pending,
          retryCount: 0,
          setLastSyncAttemptAtNull: true,
        );

        await _localDataSource.saveJob(updatedJob);
        _logger.i(
          'Successfully reset job ${updatedJob.localId} to pending state.',
        );
        return const Right(unit);
      } else {
        _logger.i(
          'Job ${job.localId} is not in failed state (${job.syncStatus}). No action taken.',
        );
        return const Right(unit); // No action needed, still considered success
      }
    } on CacheException catch (e) {
      // This catches errors during the saveJob call
      _logger.e(
        'Cache error during resetFailedJob (save operation) for $localId: $e',
      );
      return Left(
        CacheFailure(e.message ?? 'Failed to save updated job during reset'),
      );
    } catch (e) {
      // Catch any other unexpected errors
      _logger.e('Unexpected error during resetFailedJob for $localId: $e');
      return Left(CacheFailure('Unexpected error resetting job: $e'));
    }
  }

  /// Cleans up resources, including auth event subscription.
  /// This should be called when the service is no longer needed.
  ///
  /// Note on resource management:
  /// - This service is typically registered as a singleton in DI
  /// - Dispose must be called manually (e.g., during app shutdown)
  /// - StreamSubscription resources will leak if not disposed properly
  ///
  /// Note on mutex use:
  /// - The service uses a re-entrant mutex (same thread can acquire multiple times)
  /// - This prevents deadlocks during sync operations
  /// - Re-entrancy only works within the same Zone (e.g., same async call chain)
  /// - If an online event fires during a sync operation in the same Zone, it won't deadlock
  void dispose() {
    _logger.i(
      'Disposing JobSyncOrchestratorService and canceling auth event subscription',
    );
    // Make sure subscription is properly cancelled to prevent memory leaks
    if (_authEventSubscription != null) {
      _authEventSubscription!.cancel();
      _authEventSubscription = null;
      _logger.d('Auth event subscription cancelled');
    }
  }
}
