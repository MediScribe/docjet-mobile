import 'dart:async';

import 'package:docjet_mobile/core/auth/events/auth_events.dart';
import 'package:docjet_mobile/features/jobs/data/services/job_sync_trigger_service.dart';
import 'package:docjet_mobile/core/utils/log_helpers.dart';

/// A thin wrapper that starts/stops [JobSyncTriggerService] based on auth events.
///
/// Listens to a stream of [AuthEvent]s and ensures the underlying
/// [JobSyncTriggerService] only runs while the user is authenticated.
class JobSyncAuthGate {
  final JobSyncTriggerService _syncService;
  final Stream<AuthEvent> _authStream;
  late final StreamSubscription<AuthEvent> _authSub;

  final Logger _logger = LoggerFactory.getLogger(JobSyncAuthGate);
  static final String _tag = logTag(JobSyncAuthGate);

  bool _isStarted = false;
  final Completer<void> _diReady = Completer<void>();

  JobSyncAuthGate({
    required JobSyncTriggerService syncService,
    required Stream<AuthEvent> authStream,
  }) : _syncService = syncService,
       _authStream = authStream {
    _authSub = _authStream.listen(_handleAuthEvent);
  }

  /// Mark that dependency injection is fully ready.
  /// Must be called once setup is finished (e.g., after `getIt.allReady()`).
  void markDiReady() {
    if (!_diReady.isCompleted) {
      _diReady.complete();
    }
  }

  Future<void> _handleLoggedIn() async {
    try {
      // Wait until the DI container signals readiness.
      await _diReady.future;
      if (!_isStarted) {
        _logger.d('$_tag Authenticated & DI ready – starting sync service');
        _syncService.init();
        _syncService.startTimer();
        _isStarted = true;
      }
    } catch (e, st) {
      _logger.e(
        '$_tag Failed to start sync service after login',
        error: e,
        stackTrace: st,
      );
    }
  }

  void _handleAuthEvent(AuthEvent event) {
    switch (event) {
      case AuthEvent.loggedIn:
        // Fire-and-forget async handling so we don't block the event loop.
        _handleLoggedIn();
        break;
      case AuthEvent.loggedOut:
        if (_isStarted) {
          _logger.d('$_tag LoggedOut – disposing sync service');
          _syncService.dispose();
          _isStarted = false;
        }
        break;
      default:
        // Ignore other events for now
        break;
    }
  }

  /// Call to clean up subscription (e.g. on app shutdown).
  Future<void> dispose() async {
    await _authSub.cancel();
    if (_isStarted) {
      _syncService.dispose();
      _isStarted = false;
    }
  }
}
