// ignore_for_file: avoid_print
// This file will contain request handlers for debug endpoints.
import 'dart:async';
import 'dart:convert';

import 'package:mock_api_server/src/config.dart';
import 'package:mock_api_server/src/debug_helpers.dart';
import 'package:mock_api_server/src/debug_state.dart';
import 'package:mock_api_server/src/job_store.dart' as job_store;
import 'package:shelf/shelf.dart';

// --- Generic ID-based Routing Helper ---

Future<Response> routeByJobIdPresence(
  Request request,
  Future<Response> Function(Request request, String jobId) singleJobHandler,
  Future<Response> Function(Request request) allJobsHandler,
) async {
  final jobIdParam = request.url.queryParameters['id'];

  if (jobIdParam == null || jobIdParam.isEmpty) {
    // No ID or empty ID string means operate on all jobs
    return allJobsHandler(request);
  } else if (jobIdParam.trim().isEmpty) {
    // ID consists only of whitespace
    return Response.badRequest(
      body: jsonEncode(
          {'error': 'Job ID cannot be empty or just whitespace if provided.'}),
      headers: {'content-type': 'application/json'},
    );
  } else {
    // ID is present and not empty/whitespace
    return singleJobHandler(
        request, jobIdParam.trim()); // Trim the ID before passing
  }
}

// --- Handler Implementations ---

// Helper function to handle starting progression for all jobs
Future<Response> _handleStartAllJobsProgression(
    Request request, double intervalSeconds, bool fastTestMode) async {
  if (verboseLoggingEnabled) {
    print(
        'DEBUG HANDLER (START): No job ID provided. Attempting to start progression for ALL jobs.');
  }

  // Define the action for starting progression for a single job
  Future<void> startJobAction(String currentJobId,
      {Map<String, dynamic>? jobData}) async {
    Map<String, dynamic> jobToProcess;
    if (jobData != null) {
      jobToProcess = jobData;
    } else {
      try {
        jobToProcess = job_store.findJobById(currentJobId);
      } catch (e) {
        print(
            'ERROR HANDLER (START ALL): Could not find job $currentJobId to start progression: $e');
        rethrow;
      }
    }

    final jobStatus = jobToProcess['status'] as String?;
    if (jobStatus == 'completed') {
      if (verboseLoggingEnabled) {
        print(
            'DEBUG HANDLER (START ALL): Job $currentJobId is already completed. Skipping.');
      }
      return; // Skip already completed jobs
    }

    cancelProgressionTimerForJob(currentJobId);

    if (fastTestMode) {
      if (verboseLoggingEnabled) {
        print(
            'DEBUG HANDLER (START ALL): Executing FAST mode for job $currentJobId.');
      }
      executeFastModeProgression(currentJobId, jobToProcess);
    } else {
      if (verboseLoggingEnabled) {
        print(
            'DEBUG HANDLER (START ALL): Starting TIMED progression for job $currentJobId.');
      }
      startTimedProgression(currentJobId, intervalSeconds, jobToProcess);
    }
  }

  return applyActionToAllJobs(
    'Start Progression',
    startJobAction,
  );
}

/// Starts the automatic status progression for a given job.
Future<Response> startJobProgressionHandler(Request request) async {
  // Parse specific parameters for starting progression
  final params = parseStartProgressionParams(request);
  if (params.containsKey('error')) {
    return Response.badRequest(body: jsonEncode({'error': params['error']}));
  }

  final intervalSeconds = params['intervalSeconds'] as double;
  final fastTestMode = params['fastTestMode'] as bool;

  // Define the single job handler logic for starting progression
  Future<Response> singleStartHandler(Request req, String jobId) async {
    try {
      final job = job_store.findJobById(jobId); // Throws if not found
      final jobStatus = job['status'] as String?;

      if (jobStatus == 'completed') {
        return Response.ok(
          jsonEncode(
              {'message': 'Job $jobId is already completed. No action taken.'}),
          headers: {'content-type': 'application/json'},
        );
      }
      cancelProgressionTimerForJob(jobId);
      if (fastTestMode) {
        return executeFastModeProgression(jobId, job);
      } else {
        return startTimedProgression(jobId, intervalSeconds, job);
      }
    } on StateError {
      if (verboseLoggingEnabled) {
        print(
            'DEBUG HANDLER (START): Job ID $jobId not found for starting progression.');
      }
      final availableJobsList =
          job_store.getAllJobs().map((j) => j['id']).toList();
      return Response.notFound(
        jsonEncode({
          'error': 'Job ID $jobId not found.',
          'available_jobs': availableJobsList,
          'job_count': availableJobsList.length,
        }),
        headers: {'content-type': 'application/json'},
      );
    } catch (e, s) {
      print(
          'ERROR HANDLER (START): Failed to start job progression for $jobId: $e\n$s');
      return Response.internalServerError(
          body: jsonEncode(
              {'error': 'Failed to start job progression for $jobId'}));
    }
  }

  // Define the all jobs handler logic for starting progression
  Future<Response> allStartsHandler(Request req) async {
    return _handleStartAllJobsProgression(req, intervalSeconds, fastTestMode);
  }

  return routeByJobIdPresence(request, singleStartHandler, allStartsHandler);
}

// --- Stop Job Progression ---

Future<Response> _handleStopSingleJobProgression(
    Request request, String jobId) async {
  // Existing single-job stop logic
  if (jobProgressionTimers.containsKey(jobId)) {
    cancelProgressionTimerForJob(jobId);
    if (verboseLoggingEnabled) {
      print(
          'DEBUG HANDLER (STOP SINGLE): Stopped progression timer for job $jobId');
    }
    return Response.ok(
      jsonEncode({'message': 'Progression stopped for job $jobId'}),
      headers: {'content-type': 'application/json'},
    );
  } else {
    Map<String, dynamic>? job;
    try {
      job = job_store.findJobById(jobId); // Check if job exists
    } catch (e) {
      job = null;
    }

    if (job == null) {
      if (verboseLoggingEnabled) {
        print('DEBUG HANDLER (STOP SINGLE): Job $jobId not found.');
      }
      return job_store.createNotFoundResponse('Job', jobId);
    } else {
      if (verboseLoggingEnabled) {
        print(
            'DEBUG HANDLER (STOP SINGLE): Job $jobId found, but no active progression timer was running.');
      }
      return Response.ok(
        jsonEncode({
          'message':
              'Job $jobId found, but no active progression timer was running'
        }),
        headers: {'content-type': 'application/json'},
      );
    }
  }
}

Future<Response> _handleStopAllJobsProgression(Request request) async {
  if (verboseLoggingEnabled) {
    print(
        'DEBUG HANDLER (STOP ALL): Attempting to stop progression for ALL jobs.');
  }

  Future<void> stopJobAction(String jobId,
      {Map<String, dynamic>? jobData}) async {
    // The main action is just to cancel the timer.
    // We don't need to check if the job exists here, cancelProgressionTimerForJob is idempotent.
    // If a timer exists, it's cancelled. If not, nothing happens for that job ID.
    // applyActionToAllJobs will iterate through jobs from the store,
    // so we are only attempting to stop timers for existing jobs.
    if (jobProgressionTimers.containsKey(jobId)) {
      cancelProgressionTimerForJob(jobId);
      if (verboseLoggingEnabled) {
        print(
            'DEBUG HANDLER (STOP ALL): Cancelled timer for job $jobId (if active).');
      }
    } else {
      if (verboseLoggingEnabled) {
        print(
            'DEBUG HANDLER (STOP ALL): No active timer to cancel for job $jobId.');
      }
    }
    // No specific error to throw here for this action, as it's a best-effort stop.
    // applyActionToAllJobs handles reporting how many actions were attempted/successful.
  }

  return applyActionToAllJobs(
    'Stop Progression',
    stopJobAction,
  );
}

/// Stops the automatic status progression for a given job.
Future<Response> stopJobProgressionHandler(Request request) async {
  return routeByJobIdPresence(
      request, _handleStopSingleJobProgression, _handleStopAllJobsProgression);
}

// --- Reset Job Progression ---

Future<Response> _handleResetSingleJobProgression(
    Request request, String jobId) async {
  // Existing single-job reset logic
  Map<String, dynamic>? job;
  try {
    job = job_store.findJobById(jobId);
  } catch (e) {
    job = null;
  }
  if (job == null) {
    return job_store.createNotFoundResponse('Job', jobId);
  }

  String timerMessage = '';
  if (jobProgressionTimers.containsKey(jobId)) {
    cancelProgressionTimerForJob(jobId);
    timerMessage = ' Active progression timer cancelled.';
    if (verboseLoggingEnabled) {
      print(
          'DEBUG HANDLER (RESET SINGLE): Cancelled active timer for job $jobId.');
    }
  } else {
    if (verboseLoggingEnabled) {
      print(
          'DEBUG HANDLER (RESET SINGLE): No active timer found for job $jobId.');
    }
  }

  final initialStatus = jobStatusProgression[0];
  job_store.updateJobStatus(jobId, initialStatus);
  if (verboseLoggingEnabled) {
    print(
        'DEBUG HANDLER (RESET SINGLE): Job $jobId status reset to $initialStatus.');
  }

  return Response.ok(
    jsonEncode({
      'message':
          'Job $jobId reset to initial state ($initialStatus).$timerMessage'
    }),
    headers: {'content-type': 'application/json'},
  );
}

Future<Response> _handleResetAllJobsProgression(Request request) async {
  if (verboseLoggingEnabled) {
    print(
        'DEBUG HANDLER (RESET ALL): Attempting to reset progression for ALL jobs.');
  }

  Future<void> resetJobAction(String jobId,
      {Map<String, dynamic>? jobData}) async {
    bool timerCancelled = false;
    if (jobProgressionTimers.containsKey(jobId)) {
      cancelProgressionTimerForJob(jobId);
      timerCancelled = true;
    }

    final initialStatus = jobStatusProgression[0];
    final updated = job_store.updateJobStatus(jobId, initialStatus);

    if (verboseLoggingEnabled) {
      final tcMessage =
          timerCancelled ? "Timer cancelled." : "No active timer.";
      final usMessage = updated
          ? "Status reset to $initialStatus."
          : "Failed to update status (job might have been deleted during processing).";
      print('DEBUG HANDLER (RESET ALL): Job $jobId. $tcMessage $usMessage');
    }
    if (!updated) {
      // This could happen if the job was deleted between applyActionToAllJobs getting the list
      // and this action running. We can throw to have it reported in the errors list.
      throw Exception(
          'Failed to update status for job $jobId, it may no longer exist.');
    }
  }

  return applyActionToAllJobs(
    'Reset Progression',
    resetJobAction,
  );
}

/// Resets a job's status to the initial state and cancels any active progression timer.
Future<Response> resetJobProgressionHandler(Request request) async {
  return routeByJobIdPresence(request, _handleResetSingleJobProgression,
      _handleResetAllJobsProgression);
}

/// Lists all jobs in the system for debugging purposes
Future<Response> listAllJobsHandler(Request request) async {
  // Get all jobs from the store
  final allJobs = job_store.getAllJobs();

  if (verboseLoggingEnabled) {
    print('DEBUG: Listing all ${allJobs.length} jobs from debug endpoint');
  }

  // Return as JSON
  return Response.ok(
    jsonEncode({
      'jobs': allJobs,
      'count': allJobs.length,
      'message':
          'Debug endpoint: Returned all ${allJobs.length} jobs in the system'
    }),
    headers: {'content-type': 'application/json'},
  );
}

// Debug handler to get all request details (moved from server.dart)
Future<Response> debugHandler(Request request) async {
  final debugInfo = {
    'method': request.method,
    'url': request.url.toString(),
    'headers': request.headers,
    'protocolVersion': request.protocolVersion,
    'contentLength': request.contentLength,
    // Add more details as needed
  };
  // verboseLoggingEnabled is imported from config.dart
  if (verboseLoggingEnabled) {
    print(
        'DEBUG HANDLER: \n${debugInfo.entries.map((e) => '  ${e.key}: ${e.value}').join('\n')}');
  }
  return Response.ok(
    jsonEncode({'message': 'Debug information collected.', 'data': debugInfo}),
    headers: {'content-type': 'application/json'},
  );
}
