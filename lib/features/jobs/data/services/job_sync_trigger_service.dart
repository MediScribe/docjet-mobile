import 'dart:async'; // Import async for Timer

import 'package:flutter/material.dart';
import 'package:docjet_mobile/features/jobs/domain/repositories/job_repository.dart';
import 'package:docjet_mobile/core/utils/log_helpers.dart';

// Define a type alias for the timer factory at the top level
typedef TimerFactory =
    Timer Function(Duration duration, void Function(Timer timer) callback);

/// Manages periodic sync operation triggered by timer or app lifecycle events.
///
/// Listens to app lifecycle changes and uses a timer to periodically
/// trigger the synchronization of pending jobs via the [JobRepository].
class JobSyncTriggerService with WidgetsBindingObserver {
  final JobRepository _jobRepository;
  final Duration _syncInterval;
  final TimerFactory _timerFactory;
  Timer? _timer;
  bool _isInitialized = false; // Flag to prevent double initialization

  // Get a logger for this specific class
  final Logger _logger = LoggerFactory.getLogger(JobSyncTriggerService);
  // Create a tag for consistent log messages
  static final String _tag = logTag(JobSyncTriggerService);

  // Define default interval
  static const defaultSyncInterval = Duration(seconds: 15);

  JobSyncTriggerService({
    required JobRepository jobRepository,
    Duration syncInterval = defaultSyncInterval,
    TimerFactory timerFactory = Timer.periodic,
  }) : _jobRepository = jobRepository,
       _syncInterval = syncInterval,
       _timerFactory = timerFactory;
  // DO NOT add observer here
  // WidgetsBinding.instance.addObserver(this);

  /// Initializes the service by adding the lifecycle observer.
  /// Should be called once after instantiation.
  void init() {
    if (_isInitialized) return; // Prevent multiple additions
    _logger.i('$_tag Initializing and adding observer.');
    WidgetsBinding.instance.addObserver(this);
    _isInitialized = true;
    // Optionally, trigger an initial sync or check current state?
    // final currentState = WidgetsBinding.instance.lifecycleState;
    // if (currentState == AppLifecycleState.resumed) { ... }
  }

  /// Handles app lifecycle changes to manage the sync timer.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Guard against calls before init
    if (!_isInitialized) return;

    if (state == AppLifecycleState.resumed) {
      _triggerSync();
      startTimer();
      _logger.i('$_tag App resumed. Triggering sync and starting timer.');
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      stopTimer();
      _logger.i('$_tag App not resumed ($state). Stopping sync timer.');
    }
  }

  /// Triggers the synchronization process.
  Future<void> _triggerSync() async {
    _logger.d('$_tag Triggering sync via repository.');
    try {
      await _jobRepository.syncPendingJobs();
    } catch (e, s) {
      _logger.e('$_tag Error during sync trigger: $e', error: e, stackTrace: s);
    }
  }

  /// Starts the periodic sync timer.
  void startTimer() {
    // Guard against calls before init? Or let it be callable?
    // if (!_isInitialized) return;
    stopTimer();
    _logger.i('$_tag Starting sync timer with interval $_syncInterval.');
    _timer = _timerFactory(_syncInterval, (_) {
      _logger.d('$_tag Timer fired. Triggering sync.');
      _triggerSync();
    });
  }

  /// Stops the periodic sync timer.
  void stopTimer() {
    if (_timer?.isActive ?? false) {
      _logger.i('$_tag Stopping sync timer.');
      _timer?.cancel();
      _timer = null;
    }
  }

  /// Cleans up resources, like removing the lifecycle observer and stopping the timer.
  void dispose() {
    _logger.i('$_tag Disposing.');
    if (_isInitialized) {
      WidgetsBinding.instance.removeObserver(this);
    }
    stopTimer();
    _isInitialized = false; // Reset flag on dispose
  }
}
