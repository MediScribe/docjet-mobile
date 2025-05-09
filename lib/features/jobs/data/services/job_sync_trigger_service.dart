// Dart imports
import 'dart:async';

// Flutter imports (widgets only – we don't need full Material)
import 'package:flutter/widgets.dart';

// Third-party packages
import 'package:mutex/mutex.dart';

// Project imports
import 'package:docjet_mobile/core/utils/log_helpers.dart';
import 'package:docjet_mobile/features/jobs/domain/repositories/job_repository.dart';

// Define a type alias for the timer factory at the top level
typedef TimerFactory =
    Timer Function(Duration duration, void Function(Timer timer) callback);

/// Manages periodic sync operation triggered by timer or app lifecycle events.
///
/// Listens to app lifecycle changes and uses a timer to periodically
/// trigger the synchronization of pending jobs via the [JobRepository].
///
/// The sync process consists of two sequential steps:
/// 1. Push local pending changes to the server (syncPendingJobs)
/// 2. Pull server state to detect server-side deletions (reconcileJobsWithServer)
class JobSyncTriggerService with WidgetsBindingObserver {
  final JobRepository _jobRepository;
  final Duration _syncInterval;
  final TimerFactory _timerFactory;
  final Mutex _triggerMutex = Mutex(); // Mutex to prevent overlapping syncs
  Timer? _timer;
  // Flags for gating logic – sync/timer should only start once _firstFrame and
  // _authenticated are both true. These are explicitly managed via the
  // [onFirstFrameDisplayed] and [onAuthenticated] entry points.
  bool _firstFrame = false;
  bool _authenticated = false;
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

    // Defer signalling the first frame until the first frame is actually
    // rendered. This ensures that the sync logic never blocks the UI thread
    // during the critical early-render path.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => onFirstFrameDisplayed(),
    );

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
      _logger.i('$_tag App resumed – attempting to (re)start timer.');
      _tryStart();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      stopTimer();
      _logger.i('$_tag App not resumed ($state). Stopping sync timer.');
    }
  }

  /// Triggers the synchronization process.
  ///
  /// This performs both push and pull operations in sequence:
  /// 1. Push local pending changes via syncPendingJobs()
  /// 2. Pull and reconcile server state via reconcileJobsWithServer()
  ///
  /// The mutex ensures that only one sync process runs at a time,
  /// preventing race conditions between timer and lifecycle triggers.
  Future<void> _triggerSync() async {
    // Use mutex to prevent overlapping executions
    await _triggerMutex.acquire();

    try {
      // Step 1: Push local pending changes
      await _executePushSync();

      // Step 2: Pull and reconcile with server state
      await _executePullSync();
    } catch (e, s) {
      _logger.e('$_tag Error during sync trigger: $e', error: e, stackTrace: s);
    } finally {
      _triggerMutex.release();
    }
  }

  /// Executes the push synchronization (local changes → server)
  Future<void> _executePushSync() async {
    _logger.i('$_tag Triggering push sync via repository.');
    try {
      await _jobRepository.syncPendingJobs();
      _logger.i('$_tag Sync-Push OK');
    } catch (e, s) {
      _logger.e('$_tag Sync-Push FAILURE: $e', error: e, stackTrace: s);
    }
  }

  /// Executes the pull synchronization and reconciliation (server → local)
  Future<void> _executePullSync() async {
    _logger.i('$_tag Triggering pull/reconcile via repository.');
    try {
      final result = await _jobRepository.reconcileJobsWithServer();
      result.fold(
        (failure) => _logger.w('$_tag Sync-Pull FAILURE: $failure'),
        (_) => _logger.i('$_tag Sync-Pull OK'),
      );
    } catch (e, s) {
      _logger.e('$_tag Sync-Pull FAILURE: $e', error: e, stackTrace: s);
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

  /// Internal helper guarding timer/sync start. Called whenever one of the
  /// required pre-conditions changes.
  void _tryStart() {
    // Start only once all pre-conditions are satisfied and no timer is active.
    if (_firstFrame && _authenticated && _timer == null) {
      _logger.i('$_tag Preconditions met – triggering initial sync & timer.');
      _triggerSync();
      startTimer();
    }
  }

  /// Notify the service that the very first Flutter frame has been rendered.
  ///
  /// Called automatically via a `WidgetsBinding.instance.addPostFrameCallback`
  /// inside [init], but exposed publicly to make unit testing a breeze without
  /// having to spin up the full Flutter binding.
  void onFirstFrameDisplayed() {
    if (_firstFrame) return; // Idempotent
    _firstFrame = true;
    _logger.d('$_tag First frame displayed.');
    _tryStart();
  }

  /// Notify the service that the **user became authenticated**.
  ///
  /// Called exclusively by [JobSyncAuthGate]; production code should *never*
  /// call this directly. Exposed only to keep unit-testing easy and to sustain
  /// the hard separation of concerns between auth-state orchestration and the
  /// timer logic.
  void onAuthenticated() {
    if (_authenticated) return; // Idempotent
    _authenticated = true;
    _logger.d('$_tag Authenticated flag set.');
    _tryStart();
  }

  /// Notify the service that the **user logged out** – stops the timer and
  /// resets the authenticated flag. Like [onAuthenticated], this is intended
  /// for [JobSyncAuthGate] only.
  void onLoggedOut() {
    if (!_authenticated) return;
    _logger.d('$_tag Logged out – stopping timer.');
    _authenticated = false;
    stopTimer();
  }

  /// Cleans up resources, like removing the lifecycle observer and stopping the timer.
  void dispose() {
    _logger.i('$_tag Disposing.');
    if (_isInitialized) {
      WidgetsBinding.instance.removeObserver(this);
    }
    stopTimer();
    _firstFrame = false;
    _authenticated = false;
    _isInitialized = false; // Reset flag on dispose
  }
}
