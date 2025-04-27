import 'package:docjet_mobile/core/utils/log_helpers.dart';
import 'package:docjet_mobile/features/jobs/data/services/job_sync_trigger_service.dart';

/// Helper class to initialize and start the job synchronization service.
/// This is intended to be called during app initialization.
class JobSyncInitializer {
  static final Logger _logger = LoggerFactory.getLogger(JobSyncInitializer);
  static final String _tag = logTag(JobSyncInitializer);
  static bool _isInitialized = false;

  /// Initializes the provided JobSyncTriggerService.
  ///
  /// This should be called during app initialization, after the DI container
  /// is fully set up. It ensures the service is registered as an observer
  /// for app lifecycle events and starts the periodic sync timer.
  ///
  /// Returns true if initialization was successful, false otherwise.
  static bool initialize(JobSyncTriggerService syncService) {
    if (_isInitialized) {
      _logger.i('$_tag JobSyncTriggerService already initialized.');
      return true;
    }

    try {
      // Initialize the service (adds lifecycle observer)
      syncService.init();

      // Start the sync timer
      syncService.startTimer();

      _logger.i('$_tag JobSyncTriggerService initialized and timer started.');
      _isInitialized = true;
      return true;
    } catch (e, s) {
      _logger.e(
        '$_tag Error initializing JobSyncTriggerService: $e',
        error: e,
        stackTrace: s,
      );
      return false;
    }
  }
}
