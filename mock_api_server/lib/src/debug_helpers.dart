// ignore_for_file: avoid_print
// This file will contain helper functions for debug logic.
import 'dart:async';
import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:mock_api_server/src/job_store.dart' as job_store;
import 'package:mock_api_server/src/config.dart';
import 'package:mock_api_server/src/debug_state.dart'; // Import state

/// Parses query parameters for the start progression handler.
/// Returns a map with parsed values. If validation fails, the map will
/// contain an 'error' key with a description.
Map<String, dynamic> parseStartProgressionParams(Request request) {
  final jobId = request.url.queryParameters['id'];
  final intervalSecondsParam = request.url.queryParameters['interval_seconds'];
  final fastTestModeParam = request.url.queryParameters['fast_test_mode'];

  // Allow missing ID for "all jobs" later, but handle it in the handler
  // if (jobId == null || jobId.isEmpty) {
  //   return {'error': 'Missing required query parameter: id'};
  // }

  // Default interval: 3 seconds
  double intervalSeconds = 3.0;
  if (intervalSecondsParam != null) {
    final parsedInterval = double.tryParse(intervalSecondsParam);
    if (parsedInterval == null || parsedInterval <= 0) {
      return {
        'error': 'Invalid value for interval_seconds: must be a positive number'
      };
    }
    intervalSeconds = parsedInterval;
  }

  final bool fastTestMode = (fastTestModeParam?.toLowerCase() == 'true');

  return {
    'jobId': jobId, // Can be null now
    'intervalSeconds': intervalSeconds,
    'fastTestMode': fastTestMode,
  };
}

/// Executes the fast test mode progression.
Response executeFastModeProgression(String jobId, Map<String, dynamic> job) {
  // Cancel any existing timer FIRST, even in fast mode
  cancelProgressionTimerForJob(jobId);

  if (verboseLoggingEnabled) {
    print('DEBUG FAST MODE: Starting immediate progression for job $jobId...');
  }
  String currentStatus = job['job_status'];
  for (final nextStatus in jobStatusProgression) {
    // Use imported state
    final currentIndex =
        jobStatusProgression.indexOf(currentStatus); // Use imported state
    final nextIndex =
        jobStatusProgression.indexOf(nextStatus); // Use imported state
    if (nextIndex > currentIndex) {
      // Update job status immediately
      job_store.updateJobStatus(jobId, nextStatus);
      if (verboseLoggingEnabled) {
        print('DEBUG FAST MODE: Job $jobId updated to $nextStatus');
      }
      currentStatus = nextStatus; // Update local tracker for loop logic
    }
  }
  // Ensure final state is 'completed' if loop finished
  if (currentStatus != 'completed') {
    job_store.updateJobStatus(jobId, 'completed');
    if (verboseLoggingEnabled) {
      print('DEBUG FAST MODE: Job $jobId forced to completed');
    }
  }
  jobProgressionTimers.remove(jobId); // Use imported state
  if (verboseLoggingEnabled) {
    print('DEBUG FAST MODE: Progression finished for job $jobId');
  }
  return Response.ok(
    jsonEncode({'message': 'Job $jobId progression completed (fast mode)'}),
    headers: {'content-type': 'application/json'},
  );
}

/// Sets up and starts the timed progression timer.
Response startTimedProgression(
    String jobId, double intervalSeconds, Map<String, dynamic> job) {
  if (verboseLoggingEnabled) {
    print(
        'DEBUG: Starting timed progression for job $jobId every $intervalSeconds seconds');
  }
  final intervalDuration =
      Duration(milliseconds: (intervalSeconds * 1000).round());

  // Cancel existing timer FIRST before starting new one
  cancelProgressionTimerForJob(jobId);

  jobProgressionTimers[jobId] = Timer.periodic(intervalDuration, (timer) {
    // Use imported state
    handleProgressionTick(jobId, timer); // Call the public helper
  });

  return Response.ok(
    jsonEncode({
      'message': 'Job $jobId progression started every $intervalSeconds seconds'
    }),
    headers: {'content-type': 'application/json'},
  );
}

/// Handles a single tick of the job progression timer.
/// Fetches the job, determines the next state, updates it, and cancels the timer if needed.
void handleProgressionTick(String jobId, Timer timer) {
  Map<String, dynamic>? currentJob;
  try {
    currentJob = job_store.findJobById(jobId); // Fetch latest state
  } catch (e) {
    currentJob = null; // Consider job gone if store throws
  }

  // 1. Handle job not found
  if (currentJob == null) {
    if (verboseLoggingEnabled) {
      print(
          'DEBUG TIMER: Job $jobId not found during timer tick, cancelling timer.');
    }
    timer.cancel();
    jobProgressionTimers.remove(jobId); // Use imported state
    return;
  }

  final currentStatus = currentJob['job_status'];
  final nextStatus = getNextJobStatus(currentStatus); // Use public helper

  // 2. Handle progression to next state
  if (nextStatus != null) {
    if (verboseLoggingEnabled) {
      print(
          'DEBUG TIMER: Progressing job $jobId from $currentStatus to $nextStatus');
    }
    job_store.updateJobStatus(jobId, nextStatus);

    // 3. Handle completion
    if (nextStatus == 'completed') {
      if (verboseLoggingEnabled) {
        print(
            'DEBUG TIMER: Job $jobId reached completed state, cancelling timer.');
      }
      timer.cancel();
      jobProgressionTimers.remove(jobId); // Use imported state
    }
  }
  // 4. Handle end of progression (already completed or unexpected state)
  else {
    if (verboseLoggingEnabled) {
      print(
          'DEBUG TIMER: Job $jobId already completed or in unhandled state ($currentStatus), cancelling timer.');
    }
    timer.cancel();
    jobProgressionTimers.remove(jobId); // Use imported state
  }
}

/// Gets the next status in the progression sequence.
String? getNextJobStatus(String currentStatus) {
  final currentIndex =
      jobStatusProgression.indexOf(currentStatus); // Use imported state
  if (currentIndex == -1 || currentIndex >= jobStatusProgression.length - 1) {
    // Use imported state
    return null; // Not found or already at the last status
  }
  return jobStatusProgression[currentIndex + 1]; // Use imported state
}

/// Cancels any active progression timer for the specified job ID.
/// This should be called when a job is deleted or reset.
void cancelProgressionTimerForJob(String jobId) {
  if (jobProgressionTimers.containsKey(jobId)) {
    // Use imported state
    jobProgressionTimers[jobId]?.cancel();
    jobProgressionTimers.remove(jobId); // Use imported state
    if (verboseLoggingEnabled) {
      print('DEBUG CLEANUP: Cancelled timer for job $jobId.');
    }
  } else {
    if (verboseLoggingEnabled) {
      print('DEBUG CLEANUP: No active timer found for job $jobId.');
    }
  }
}
