// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:mock_api_server/src/job_store.dart' as job_store;
import 'package:mock_api_server/src/config.dart';
import 'package:shelf/shelf.dart';

// --- State ---

/// Stores active progression timers, keyed by job ID.
final Map<String, Timer> _jobProgressionTimers = {};

/// The defined sequence of job statuses for progression.
const List<String> _jobStatusProgression = [
  // 'created', // REMOVED: Server receives jobs starting at 'submitted'
  'submitted',
  'transcribing',
  'transcribed',
  'generating',
  'generated',
  'completed',
];

// --- Handlers ---

/// Parses query parameters for the start progression handler.
/// Returns a map with parsed values or null if validation fails.
Map<String, dynamic>? _parseStartProgressionParams(Request request) {
  final jobId = request.url.queryParameters['id'];
  final intervalSecondsParam = request.url.queryParameters['interval_seconds'];
  final fastTestModeParam = request.url.queryParameters['fast_test_mode'];

  if (jobId == null || jobId.isEmpty) {
    return {'error': 'Missing required query parameter: id'};
  }

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
    'jobId': jobId,
    'intervalSeconds': intervalSeconds,
    'fastTestMode': fastTestMode,
  };
}

/// Executes the fast test mode progression.
Response _executeFastModeProgression(String jobId, Map<String, dynamic> job) {
  if (verboseLoggingEnabled) {
    print('DEBUG FAST MODE: Starting immediate progression for job $jobId...');
  }
  String currentStatus = job['job_status'];
  for (final nextStatus in _jobStatusProgression) {
    final currentIndex = _jobStatusProgression.indexOf(currentStatus);
    final nextIndex = _jobStatusProgression.indexOf(nextStatus);
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
  _jobProgressionTimers.remove(jobId); // No timer needed
  if (verboseLoggingEnabled) {
    print('DEBUG FAST MODE: Progression finished for job $jobId');
  }
  return Response.ok(
    jsonEncode({'message': 'Job $jobId progression completed (fast mode)'}),
    headers: {'content-type': 'application/json'},
  );
}

/// Sets up and starts the timed progression timer.
Response _startTimedProgression(
    String jobId, double intervalSeconds, Map<String, dynamic> job) {
  if (verboseLoggingEnabled) {
    print(
        'DEBUG: Starting timed progression for job $jobId every $intervalSeconds seconds');
  }
  final intervalDuration =
      Duration(milliseconds: (intervalSeconds * 1000).round());

  _jobProgressionTimers[jobId] = Timer.periodic(intervalDuration, (timer) {
    _handleProgressionTick(jobId, timer); // Call the new helper
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
void _handleProgressionTick(String jobId, Timer timer) {
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
    _jobProgressionTimers.remove(jobId);
    return;
  }

  final currentStatus = currentJob['job_status'];
  final nextStatus = _getNextJobStatus(currentStatus);

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
      _jobProgressionTimers.remove(jobId);
    }
  }
  // 4. Handle end of progression (already completed or unexpected state)
  else {
    if (verboseLoggingEnabled) {
      print(
          'DEBUG TIMER: Job $jobId already completed or in unhandled state ($currentStatus), cancelling timer.');
    }
    timer.cancel();
    _jobProgressionTimers.remove(jobId);
  }
}

/// Starts the automatic status progression for a given job.
Future<Response> startJobProgressionHandler(Request request) async {
  // 1. Parse and validate parameters
  final params = _parseStartProgressionParams(request);
  if (params == null || params.containsKey('error')) {
    return Response(
      HttpStatus.badRequest, // 400
      body: jsonEncode({'error': params?['error'] ?? 'Invalid parameters'}),
      headers: {'content-type': 'application/json'},
    );
  }
  final jobId = params['jobId'] as String;
  final intervalSeconds = params['intervalSeconds'] as double;
  final fastTestMode = params['fastTestMode'] as bool;

  // 2. Find the job
  Map<String, dynamic>? job;
  try {
    job = job_store.findJobById(jobId);
  } catch (e) {
    job = null;
  }
  if (job == null) {
    return job_store.createNotFoundResponse('Job', jobId);
  }

  // 3. Check if already completed
  if (job['job_status'] == 'completed') {
    return Response(
      HttpStatus.badRequest, // 400
      body: jsonEncode({'error': 'Job $jobId is already completed'}),
      headers: {'content-type': 'application/json'},
    );
  }

  // 4. Cancel existing timer (idempotent)
  if (_jobProgressionTimers.containsKey(jobId)) {
    if (verboseLoggingEnabled) {
      print(
          'DEBUG: Cancelling existing timer for job $jobId before starting new progression.');
    }
    _jobProgressionTimers[jobId]?.cancel();
    _jobProgressionTimers.remove(jobId); // Ensure removal after cancel
  }

  // 5. Execute fast mode or start timer
  if (fastTestMode) {
    return _executeFastModeProgression(jobId, job);
  } else {
    return _startTimedProgression(jobId, intervalSeconds, job);
  }
}

/// Stops the automatic status progression for a given job.
Future<Response> stopJobProgressionHandler(Request request) async {
  final jobId = request.url.queryParameters['id'];

  if (jobId == null || jobId.isEmpty) {
    return Response(
      HttpStatus.badRequest, // 400
      body: jsonEncode({'error': 'Missing required query parameter: id'}),
      headers: {'content-type': 'application/json'},
    );
  }

  if (_jobProgressionTimers.containsKey(jobId)) {
    _jobProgressionTimers[jobId]?.cancel();
    _jobProgressionTimers.remove(jobId);
    if (verboseLoggingEnabled) {
      print('DEBUG: Stopped progression timer for job $jobId');
    }
    return Response.ok(
      jsonEncode({'message': 'Progression stopped for job $jobId'}),
      headers: {'content-type': 'application/json'},
    );
  } else {
    // Check if the job exists even if no timer is running
    Map<String, dynamic>? job;
    try {
      job = job_store.findJobById(jobId);
    } catch (e) {
      job = null;
    }

    if (job == null) {
      return job_store.createNotFoundResponse('Job', jobId);
    } else {
      // Job exists but no timer was running
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

// --- Helper Functions (Potentially move or keep here) ---

/// Gets the next status in the progression sequence.
String? _getNextJobStatus(String currentStatus) {
  final currentIndex = _jobStatusProgression.indexOf(currentStatus);
  if (currentIndex == -1 || currentIndex >= _jobStatusProgression.length - 1) {
    return null; // Not found or already at the last status
  }
  return _jobStatusProgression[currentIndex + 1];
}

/// Cleans up a timer associated with a job ID, typically called when a job is deleted.
void cleanupJobProgressionTimer(String jobId) {
  if (_jobProgressionTimers.containsKey(jobId)) {
    _jobProgressionTimers[jobId]?.cancel();
    _jobProgressionTimers.remove(jobId);
    if (verboseLoggingEnabled) {
      print(
          'DEBUG CLEANUP: Removed active progression timer for deleted job $jobId');
    }
  }
}

// --- New Reset Handler ---

/// Resets a job's status to the initial state and cancels any active progression timer.
Future<Response> resetJobProgressionHandler(Request request) async {
  final jobId = request.url.queryParameters['id'];

  if (jobId == null || jobId.isEmpty) {
    return Response(
      HttpStatus.badRequest, // 400
      body: jsonEncode({'error': 'Missing required query parameter: id'}),
      headers: {'content-type': 'application/json'},
    );
  }

  // 1. Find the job
  Map<String, dynamic>? job;
  try {
    job = job_store.findJobById(jobId);
  } catch (e) {
    job = null;
  }
  if (job == null) {
    return job_store.createNotFoundResponse('Job', jobId);
  }

  // 2. Cancel existing timer (idempotent)
  String timerMessage = '';
  if (_jobProgressionTimers.containsKey(jobId)) {
    _jobProgressionTimers[jobId]?.cancel();
    _jobProgressionTimers.remove(jobId);
    timerMessage = ' Active progression timer cancelled.';
    if (verboseLoggingEnabled) {
      print('DEBUG RESET: Cancelled active timer for job $jobId.');
    }
  } else {
    if (verboseLoggingEnabled) {
      print('DEBUG RESET: No active timer found for job $jobId.');
    }
  }

  // 3. Reset status to the initial one in the progression
  final initialStatus = _jobStatusProgression[0]; // Should be 'submitted'
  job_store.updateJobStatus(jobId, initialStatus);
  if (verboseLoggingEnabled) {
    print('DEBUG RESET: Job $jobId status reset to $initialStatus.');
  }

  // 4. Return success response
  return Response.ok(
    jsonEncode({
      'message':
          'Job $jobId reset to initial state ($initialStatus).$timerMessage'
    }),
    headers: {'content-type': 'application/json'},
  );
}

// --- Public Helper Functions ---

/// Cancels any active progression timer for the specified job ID.
/// This should be called when a job is deleted.
void cancelProgressionTimerForJob(String jobId) {
  if (_jobProgressionTimers.containsKey(jobId)) {
    _jobProgressionTimers[jobId]?.cancel();
    _jobProgressionTimers.remove(jobId);
    if (verboseLoggingEnabled) {
      print('DEBUG CLEANUP: Cancelled timer for deleted/reset job $jobId.');
    }
  } else {
    if (verboseLoggingEnabled) {
      print(
          'DEBUG CLEANUP: No active timer found for deleted/reset job $jobId.');
    }
  }
}
