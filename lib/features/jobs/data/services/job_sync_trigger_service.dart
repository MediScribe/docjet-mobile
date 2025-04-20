import 'dart:async'; // Import async for Timer

import 'package:flutter/material.dart';
import 'package:docjet_mobile/features/jobs/data/services/job_sync_orchestrator_service.dart';

/// Manages periodic sync operation triggered by timer or app lifecycle events.
///
/// Listens to app lifecycle changes and uses a timer to periodically
/// trigger the synchronization of pending jobs via the [JobSyncOrchestratorService].
class JobSyncTriggerService with WidgetsBindingObserver {
  final JobSyncOrchestratorService _orchestratorService;
  final Duration _syncInterval;
  Timer? _timer;

  // Define default interval
  static const defaultSyncInterval = Duration(seconds: 15);

  JobSyncTriggerService({
    required JobSyncOrchestratorService orchestratorService,
    Duration syncInterval = defaultSyncInterval,
  }) : _orchestratorService = orchestratorService,
       _syncInterval = syncInterval {
    WidgetsBinding.instance.addObserver(this);
  }

  /// Handles app lifecycle changes to manage the sync timer.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Implementation to be added and tested later
    if (state == AppLifecycleState.resumed) {
      // Placeholder: We'll add the actual call in the next TDD step (GREEN)
      _orchestratorService.syncPendingJobs();
      debugPrint('[JobSyncTriggerService] App resumed. Triggering sync.');
    } else {
      // Placeholder: We'll add timer cancellation logic later
      debugPrint(
        '[JobSyncTriggerService] App not resumed. Stopping sync timer (placeholder).',
      );
    }
  }

  /// Starts the periodic sync timer.
  void startTimer() {
    // Ensure we don't start multiple timers
    stopTimer();
    debugPrint(
      '[JobSyncTriggerService] Starting sync timer with interval $_syncInterval.',
    );
    _timer = Timer.periodic(_syncInterval, (_) {
      debugPrint('[JobSyncTriggerService] Timer fired. Triggering sync.');
      _orchestratorService.syncPendingJobs();
    });
  }

  /// Stops the periodic sync timer.
  void stopTimer() {
    if (_timer?.isActive ?? false) {
      debugPrint('[JobSyncTriggerService] Stopping sync timer.');
      _timer?.cancel();
      _timer = null;
    }
  }

  /// Cleans up resources, like removing the lifecycle observer and stopping the timer.
  void dispose() {
    debugPrint('[JobSyncTriggerService] Disposing.');
    WidgetsBinding.instance.removeObserver(this);
    stopTimer(); // Call stopTimer to cancel any active timer
  }
}
