import 'package:docjet_mobile/core/utils/log_helpers.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/sync_status.dart';

/// Enhanced logging utility for JobSyncService
/// Used for detailed debugging during sync operations and tests
class JobSyncLogger {
  static final Logger _logger = LoggerFactory.getLogger('JobSyncDebug');
  static const String _tag = '[JobSyncDebug]';

  // Enable full debug logs for all test runs
  static void enableDebugLogs() {
    LoggerFactory.setLogLevel('JobSyncDebug', Level.debug);
  }

  // Clear all previously captured logs
  static void clearLogs() {
    LoggerFactory.clearLogs();
  }

  // Detailed job information logging
  static void logJobDetails(String prefix, Job job) {
    _logger.d('$_tag $prefix JOB DETAILS:');
    _logger.d('$_tag   localId: ${job.localId}');
    _logger.d('$_tag   serverId: ${job.serverId}');
    _logger.d('$_tag   syncStatus: ${job.syncStatus}');
    _logger.d('$_tag   retryCount: ${job.retryCount}');
    _logger.d('$_tag   lastSyncAttemptAt: ${job.lastSyncAttemptAt}');
    _logger.d('$_tag   audioFilePath: ${job.audioFilePath}');
    _logger.d('$_tag   userId: ${job.userId}');
    _logger.d('$_tag   createdAt: ${job.createdAt}');
    _logger.d('$_tag   updatedAt: ${job.updatedAt}');
  }

  // Log multiple jobs with summary
  static void logJobList(String operation, List<Job> jobs) {
    _logger.i('$_tag $operation - Found ${jobs.length} jobs');
    if (jobs.isEmpty) {
      _logger.d('$_tag   No jobs found');
      return;
    }

    // Log count by status
    final statusCounts = <SyncStatus, int>{};
    for (final job in jobs) {
      statusCounts[job.syncStatus] = (statusCounts[job.syncStatus] ?? 0) + 1;
    }

    for (final entry in statusCounts.entries) {
      _logger.d('$_tag   ${entry.key}: ${entry.value} job(s)');
    }

    // Print details for each job
    for (int i = 0; i < jobs.length; i++) {
      _logger.d('$_tag --- Job ${i + 1}/${jobs.length} ---');
      logJobDetails('', jobs[i]);
    }
  }

  // Log method entry with arguments
  static void logMethodEntry(String methodName, {Map<String, dynamic>? args}) {
    final argsStr = args != null ? ' with args: $args' : '';
    _logger.i('$_tag ENTER: $methodName$argsStr');
  }

  // Log method exit with result
  static void logMethodExit(String methodName, {dynamic result}) {
    final resultStr = result != null ? ' with result: $result' : '';
    _logger.i('$_tag EXIT: $methodName$resultStr');
  }

  // Log sync operations
  static void logSyncOperation(
    String operation,
    String localId, {
    String? serverId,
    String? message,
  }) {
    final serverIdStr = serverId != null ? ', serverId: $serverId' : '';
    final messageStr = message != null ? ' - $message' : '';
    _logger.i(
      '$_tag $operation for job (localId: $localId$serverIdStr)$messageStr',
    );
  }

  // Log error with enhanced details
  static void logError(
    String operation,
    String localId,
    dynamic error, {
    Job? job,
    String? additionalInfo,
  }) {
    _logger.e('$_tag ERROR in $operation for job $localId: $error');

    if (additionalInfo != null) {
      _logger.e('$_tag   Additional info: $additionalInfo');
    }

    if (job != null) {
      _logger.e('$_tag   Current job state:');
      logJobDetails('  ', job);
    }

    // Log stack trace if available
    if (error is Error) {
      _logger.e('$_tag   Stack trace: ${error.stackTrace}');
    }
  }

  // Log retry information
  static void logRetryInfo(Job job, int maxRetries, Duration baseBackoff) {
    final backoffSeconds =
        (baseBackoff.inSeconds * (1 << job.retryCount)).toInt();
    final retriesRemaining = maxRetries - job.retryCount;

    _logger.i('$_tag RETRY INFO for job ${job.localId}:');
    _logger.i('$_tag   Current retry count: ${job.retryCount}/$maxRetries');
    _logger.i('$_tag   Retries remaining: $retriesRemaining');
    _logger.i('$_tag   Last attempt: ${job.lastSyncAttemptAt}');
    _logger.i('$_tag   Next attempt backoff: $backoffSeconds seconds');

    if (retriesRemaining <= 0) {
      _logger.w(
        '$_tag   ⚠️ NO RETRIES REMAINING - Job will be marked as FAILED',
      );
    }
  }

  // Log state transition
  static void logStateTransition(
    String localId,
    SyncStatus oldStatus,
    SyncStatus newStatus, {
    String? reason,
  }) {
    final reasonStr = reason != null ? ' - Reason: $reason' : '';
    _logger.i(
      '$_tag STATE CHANGE for job $localId: $oldStatus → $newStatus$reasonStr',
    );
  }

  // Log network state
  static void logNetworkState(bool isConnected) {
    _logger.i('$_tag NETWORK STATE: ${isConnected ? "ONLINE" : "OFFLINE"}');
  }

  // Log mutex operations
  static void logMutexOperation(String operation) {
    _logger.d('$_tag MUTEX: $operation');
  }
}
