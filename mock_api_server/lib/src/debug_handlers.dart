// ignore_for_file: avoid_print
// This file will contain request handlers for debug endpoints.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:mock_api_server/src/job_store.dart' as job_store;
import 'package:mock_api_server/src/config.dart';
import 'package:mock_api_server/src/debug_state.dart';
import 'package:mock_api_server/src/debug_helpers.dart';

/// Starts the automatic status progression for a given job.
Future<Response> startJobProgressionHandler(Request request) async {
  // 1. Parse and validate parameters
  final params = parseStartProgressionParams(request); // Use helper
  if (params.containsKey('error')) {
    return Response(
      HttpStatus.badRequest, // 400
      body: jsonEncode({'error': params['error']}),
      headers: {'content-type': 'application/json'},
    );
  }
  // ID is now nullable in params, handle potential null here or in next cycle
  final jobId = params['jobId'] as String?;
  final intervalSeconds = params['intervalSeconds'] as double;
  final fastTestMode = params['fastTestMode'] as bool;

  // Handle missing ID (for now, return error until Cycle 1)
  if (jobId == null || jobId.isEmpty) {
    return Response(
      HttpStatus.badRequest, // 400
      body: jsonEncode({
        'error':
            'Missing required query parameter: id (all-jobs not implemented yet)'
      }),
      headers: {'content-type': 'application/json'},
    );
  }

  // 2. Find the job
  Map<String, dynamic>? job;
  try {
    job = job_store.findJobById(jobId);
  } catch (e) {
    job = null;
  }
  if (job == null) {
    // REVERT: Return 404 with available jobs for test compatibility
    final allJobs = job_store.getAllJobs();
    if (verboseLoggingEnabled) {
      print(
          'DEBUG START HANDLER: Job $jobId not found. Returning all ${allJobs.length} available jobs.');
    }
    return Response(
      HttpStatus.notFound, // Still 404 but with helpful data
      body: jsonEncode({
        'error': 'Job with ID $jobId not found',
        'available_jobs': allJobs,
        'job_count': allJobs.length,
        'help': 'These are all available jobs on the server'
      }),
      headers: {'content-type': 'application/json'},
    );
  }

  // 3. Check if already completed
  if (job['job_status'] == 'completed') {
    return Response(
      HttpStatus.badRequest, // 400
      body: jsonEncode({'error': 'Job $jobId is already completed'}),
      headers: {'content-type': 'application/json'},
    );
  }

  // 4. Cancel existing timer (handled within helpers now)
  // cancelProgressionTimerForJob(jobId); // Called by startTimedProgression

  // 5. Execute fast mode or start timer using helpers
  if (fastTestMode) {
    return executeFastModeProgression(jobId, job); // Use helper
  } else {
    return startTimedProgression(jobId, intervalSeconds, job); // Use helper
  }
}

/// Stops the automatic status progression for a given job.
Future<Response> stopJobProgressionHandler(Request request) async {
  final jobId = request.url.queryParameters['id'];

  if (jobId == null || jobId.isEmpty) {
    return Response(
      HttpStatus.badRequest, // 400
      body: jsonEncode({
        'error':
            'Missing required query parameter: id (all-jobs not implemented yet)'
      }),
      headers: {'content-type': 'application/json'},
    );
  }

  if (jobProgressionTimers.containsKey(jobId)) {
    // Use state
    cancelProgressionTimerForJob(jobId); // Use helper
    if (verboseLoggingEnabled) {
      print('DEBUG: Stopped progression timer for job $jobId');
    }
    return Response.ok(
      jsonEncode({'message': 'Progression stopped for job $jobId'}),
      headers: {'content-type': 'application/json'},
    );
  } else {
    Map<String, dynamic>? job;
    try {
      job = job_store.findJobById(jobId);
    } catch (e) {
      job = null;
    }

    if (job == null) {
      return job_store.createNotFoundResponse('Job', jobId);
    } else {
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

/// Resets a job's status to the initial state and cancels any active progression timer.
Future<Response> resetJobProgressionHandler(Request request) async {
  final jobId = request.url.queryParameters['id'];

  if (jobId == null || jobId.isEmpty) {
    return Response(
      HttpStatus.badRequest, // 400
      body: jsonEncode({
        'error':
            'Missing required query parameter: id (all-jobs not implemented yet)'
      }),
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
  if (jobProgressionTimers.containsKey(jobId)) {
    // Use state
    cancelProgressionTimerForJob(jobId); // Use helper
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
  final initialStatus = jobStatusProgression[0]; // Use state
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
