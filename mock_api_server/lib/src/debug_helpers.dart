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

/// Applies an action to all jobs in the store.
///
/// Takes an action name for logging, and a job action function.
/// The job action function will be called for each job in the store,
/// using the global `job_store.getAllJobs()` to retrieve jobs.
/// Returns a shelf Response with a success message indicating how many jobs were processed.
Future<Response> applyActionToAllJobs(
  // dynamic jobStore, // Removed: will use job_store.getAllJobs() directly
  String actionName,
  Future<void> Function(String jobId, {Map<String, dynamic> jobData}) jobAction,
) async {
  final List<Map<String, dynamic>> allJobs;
  try {
    allJobs = job_store.getAllJobs(); // Directly use the global store
  } catch (e, s) {
    print('ERROR: Failed to get all jobs from store: $e\n$s');
    // TODO: Consider a more user-friendly error response if this is user-facing
    return Response.internalServerError(
        body: jsonEncode({
      'error': 'Failed to retrieve jobs from store',
      'details': e.toString(),
    }));
  }

  if (verboseLoggingEnabled) {
    print('DEBUG APPLY_ALL: Action "$actionName" initiated for all jobs.');
  }

  var successCounter = 0;
  final List<String> errorMessages = [];

  if (allJobs.isEmpty) {
    if (verboseLoggingEnabled) {
      print('DEBUG APPLY_ALL: No jobs found in store to apply "$actionName".');
    }
    return Response.ok(
      jsonEncode({'message': '$actionName applied to 0 jobs. No jobs found.'}),
      headers: {'content-type': 'application/json'},
    );
  }

  for (final job in allJobs) {
    final jobId = job['id'] as String?;
    if (jobId == null) {
      final errorMessage =
          'Error applying $actionName: Job found with null ID. Skipping.';
      print('ERROR APPLY_ALL: $errorMessage Job data: $job');
      errorMessages.add(errorMessage);
      continue;
    }
    try {
      // Pass the full job data to the action, if it needs it.
      await jobAction(jobId, jobData: job);
      successCounter++;
      if (verboseLoggingEnabled) {
        print(
            'DEBUG APPLY_ALL: Successfully applied "$actionName" to job $jobId.');
      }
    } catch (e, s) {
      final errorMessage =
          'Error applying $actionName to job $jobId: ${e.toString()}';
      print('ERROR APPLY_ALL: $errorMessage\nStack trace:\n$s');
      errorMessages.add(errorMessage);
      // Continue to the next job even if one fails
    }
  }

  final Map<String, dynamic> responseBody = {
    'message':
        '$actionName applied to $successCounter out of ${allJobs.length} jobs.',
    'successful_applications': successCounter,
    'total_jobs_processed': allJobs.length,
  };

  if (errorMessages.isNotEmpty) {
    responseBody['errors'] = errorMessages;
    responseBody['error_count'] = errorMessages.length;
    if (verboseLoggingEnabled) {
      print(
          'DEBUG APPLY_ALL: Action "$actionName" completed with ${errorMessages.length} errors.');
    }
    // Return 207 Multi-Status if there were errors but some successes
    if (successCounter > 0 && successCounter < allJobs.length) {
      return Response(
        207, // Multi-Status
        body: jsonEncode(responseBody),
        headers: {'content-type': 'application/json'},
      );
    }
    // Return 500 if all attempts failed or if there were only errors (and no successes)
    // or if there were successes but the overall operation is considered a failure due to errors.
    // For now, let's assume any error makes the "all" operation problematic.
    // If all jobs resulted in an error, or if there were errors.
    // This can be refined based on how strictly we want to report partial success.
    // For now, if there are any errors, let's not return a simple 200 OK.
    return Response.internalServerError(
      body: jsonEncode(responseBody),
      headers: {'content-type': 'application/json'},
    );
  }

  if (verboseLoggingEnabled) {
    print(
        'DEBUG APPLY_ALL: Action "$actionName" completed successfully for all $successCounter jobs.');
  }
  return Response.ok(
    jsonEncode(responseBody),
    headers: {'content-type': 'application/json'},
  );
}
