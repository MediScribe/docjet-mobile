/// Defines request handlers for all job-related CRUD (Create, Read, Update, Delete)
/// operations, including creating new jobs, listing jobs, retrieving job details,
/// fetching job documents, updating job statuses/attributes, and deleting jobs.
// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf_multipart/shelf_multipart.dart';

// Core utilities and constants
import 'package:mock_api_server/src/core/utils.dart';

// Job store
import 'package:mock_api_server/src/job_store.dart' as job_store;

// Config for logging
import 'package:mock_api_server/src/config.dart';

// Debug helpers
import 'package:mock_api_server/src/debug_helpers.dart';

// Create Job handler logic
Future<Response> createJobHandler(Request request) async {
  if (verboseLoggingEnabled) {
    print(
        'DEBUG CREATE JOB: Content-Type is ${request.headers['content-type']}');
  }

  // Additional debugging for the request
  if (verboseLoggingEnabled) {
    print('DEBUG CREATE JOB: All headers:');
    request.headers.forEach((name, value) {
      print('  $name: $value');
    });
  }

  // IMPORTANT: DO NOT read the request body here as it can only be read once
  if (verboseLoggingEnabled) {
    print('DEBUG CREATE JOB: Processing multipart request');
  }

  // More lenient check for multipart content type
  if (request.headers['content-type'] == null ||
      !request.headers['content-type']!
          .toLowerCase()
          .contains('multipart/form-data')) {
    if (verboseLoggingEnabled) {
      print(
          'DEBUG CREATE JOB: Not a valid multipart request. Content-Type: ${request.headers['content-type']}');
    }
    return Response(
      HttpStatus.badRequest,
      body: jsonEncode(
          {'error': 'Expected Content-Type containing multipart/form-data'}),
      headers: {'content-type': 'application/json'},
    );
  }

  String? userId;
  String? text;
  String? additionalText;
  bool hasAudioFile = false;

  try {
    if (verboseLoggingEnabled) {
      print('DEBUG CREATE JOB: Processing multipart request');
    }

    // First, ensure we have a multipart request
    final multipartRequest = request.multipart();
    if (multipartRequest == null) {
      throw const FormatException('Could not parse as multipart request');
    }

    // Initialize variables to store form data
    userId = null;
    text = null;
    additionalText = null;
    hasAudioFile = false;

    // Process the multipart parts directly without storing them first
    await for (final part in multipartRequest.parts) {
      final headers = part.headers;
      if (verboseLoggingEnabled) {
        print('DEBUG CREATE JOB: Part headers: $headers');
      }

      final contentDisposition = headers['content-disposition'];
      if (contentDisposition == null) {
        if (verboseLoggingEnabled) {
          print('DEBUG CREATE JOB: Missing Content-Disposition header in part');
        }
        continue;
      }

      // Extract field name and filename
      final nameMatch =
          RegExp(r'name="([^\"]*)"').firstMatch(contentDisposition);
      final filenameMatch =
          RegExp(r'filename=\"([^\"]*)\"').firstMatch(contentDisposition);

      final name = nameMatch?.group(1);
      final filename = filenameMatch?.group(1);

      if (name == null) {
        if (verboseLoggingEnabled) {
          print(
              'DEBUG CREATE JOB: Could not find name in Content-Disposition: $contentDisposition');
        }
        continue;
      }

      if (verboseLoggingEnabled) {
        print(
            'DEBUG CREATE JOB: Processing part with name: $name, filename: $filename');
      }

      // Check if this is a file by looking for a filename
      if (filename != null) {
        if (name == 'audio_file') {
          if (verboseLoggingEnabled) {
            print(
                'DEBUG CREATE JOB: Found audio_file upload with filename: $filename');
          }
          hasAudioFile = true;
          // Just consume the bytes - in a real implementation we might save the file
          await part
              .drain(); // MimeMultipart extends Stream<List<int>> so we can use drain()
        }
      } else {
        // Regular form field
        final value = await readAsString(part);
        if (verboseLoggingEnabled) {
          print('DEBUG CREATE JOB: Field $name = $value');
        }

        if (name == 'user_id') {
          userId = value;
        } else if (name == 'text') {
          text = value;
        } else if (name == 'additional_text') {
          additionalText = value;
        }
      }
    }

    // Validate required fields
    if (userId == null || userId.isEmpty) {
      throw const FormatException('Missing or empty user_id field');
    }
    if (!hasAudioFile) {
      throw const FormatException('Missing audio_file part');
    }

    // Create and store the job
    final now = DateTime.now().toUtc().toIso8601String();
    final newJob = {
      'id': uuid.v4(),
      'user_id': userId,
      'job_status': 'submitted',
      'error_code': null,
      'error_message': null,
      'created_at': now,
      'updated_at': now,
      'text': text,
      'additional_text': additionalText,
      'display_title': null,
      'display_text': null,
      'transcript': null,
      'audio_file_path': null,
    };

    job_store.addJob(newJob);

    // Prepare response data
    final responseData = {
      'id': newJob['id'],
      'user_id': newJob['user_id'],
      'job_status': newJob['job_status'],
      'created_at': newJob['created_at'],
      'updated_at': newJob['updated_at'],
      'text': newJob['text'],
      'additional_text': newJob['additional_text'],
    };

    return Response.ok(
      jsonEncode({'data': responseData}),
      headers: {'content-type': 'application/json'},
    );
  } catch (e, stackTrace) {
    // Handle potential multipart parsing errors or validation FormatExceptions
    if (verboseLoggingEnabled) {
      print('DEBUG CREATE JOB ERROR: $e');
      print('Stack trace: $stackTrace');
    }
    return Response(
      HttpStatus.badRequest, // 400
      body: jsonEncode({'error': 'Failed to process request: ${e.toString()}'}),
      headers: {'content-type': 'application/json'},
    );
  }
}

// List Jobs handler logic
Future<Response> listJobsHandler(Request request) async {
  // Authentication and API key are already handled by middleware

  // Prepare the response data - we need to return a list of job summaries.
  final responseData = job_store
      .getAllJobs()
      .map((job) => {
            'id': job['id'],
            'user_id': job['user_id'],
            'job_status': job['job_status'],
            'error_code': job['error_code'],
            'error_message': job['error_message'],
            'created_at': job['created_at'],
            'updated_at': job['updated_at'],
            'text': job['text'],
            'additional_text': job['additional_text'],
          })
      .toList(); // Convert the iterable to a list

  return Response.ok(
    jsonEncode({'data': responseData}),
    headers: {'content-type': 'application/json'},
  );
}

// Get Job By ID handler logic
Future<Response> getJobByIdHandler(Request request, String id) async {
  try {
    final job = job_store.findJobById(id);
    return Response.ok(
      jsonEncode({'data': job}),
      headers: {'content-type': 'application/json'},
    );
  } on StateError {
    return Response.notFound(
      jsonEncode({'error': 'Job with ID $id not found'}),
      headers: {'content-type': 'application/json'},
    );
  }
}

// Get Job Documents handler (Placeholder - not fully implemented in original)
Future<Response> getJobDocumentsHandler(Request request, String id) async {
  try {
    final job = job_store.findJobById(id);
    // In a real scenario, this would fetch/generate documents related to the job.
    // For this mock, we'll return a placeholder or perhaps some job details.
    final documents = [
      {
        'id': 'doc_123',
        'job_id': id,
        'type': 'transcript_plain_text',
        'content': job['transcript'] ?? 'No transcript available.',
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'url': '/api/v1/jobs/$id/documents/doc_123/content',
      },
      {
        'id': 'doc_456',
        'job_id': id,
        'type': 'summary_short',
        'content': 'This is a short summary for job $id.',
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'url': '/api/v1/jobs/$id/documents/doc_456/content',
      }
    ];

    return Response.ok(
      jsonEncode({'data': documents}),
      headers: {'content-type': 'application/json'},
    );
  } on StateError {
    return Response.notFound(
      jsonEncode({'error': 'Job with ID $id not found'}),
      headers: {'content-type': 'application/json'},
    );
  }
}

// Update Job handler logic
Future<Response> updateJobHandler(Request request, String id) async {
  // Check Content-Type header
  final contentType = request.headers[HttpHeaders.contentTypeHeader];
  if (contentType == null ||
      !contentType.toLowerCase().contains('application/json')) {
    return Response(
      HttpStatus.badRequest,
      body: jsonEncode({'error': 'Expected Content-Type: application/json'}),
      headers: {'content-type': 'application/json'},
    );
  }

  // Verify job exists
  try {
    // Just verify job exists, we'll use updateJob later
    job_store.findJobById(id);
  } on StateError {
    return Response.notFound(
      jsonEncode({'error': 'Job with ID $id not found'}),
      headers: {'content-type': 'application/json'},
    );
  }

  final payload = jsonDecode(await request.readAsString());
  final String? newStatus = payload['job_status'] as String?;
  final String? errorCode = payload['error_code'] as String?;
  final String? errorMessage = payload['error_message'] as String?;
  final String? text = payload['text'] as String?;
  final String? transcript = payload['transcript'] as String?;
  final String? displayTitle = payload['display_title'] as String?;
  final String? displayText = payload['display_text'] as String?;

  if (newStatus == null &&
      errorCode == null &&
      errorMessage == null &&
      text == null &&
      transcript == null &&
      displayTitle == null &&
      displayText == null) {
    return Response(
      HttpStatus.badRequest,
      body: jsonEncode({
        'error':
            'At least one field (job_status, error_code, error_message, text, transcript, display_title, display_text) must be provided for update'
      }),
      headers: {'content-type': 'application/json'},
    );
  }

  final updatedFields = <String, dynamic>{};
  if (newStatus != null) updatedFields['job_status'] = newStatus;
  if (errorCode != null) updatedFields['error_code'] = errorCode;
  if (errorMessage != null) updatedFields['error_message'] = errorMessage;
  if (text != null) updatedFields['text'] = text;
  if (transcript != null) updatedFields['transcript'] = transcript;
  if (displayTitle != null) updatedFields['display_title'] = displayTitle;
  if (displayText != null) updatedFields['display_text'] = displayText;

  // If job is transitioning to a final state, cancel any progression timer
  if (newStatus != null &&
      (newStatus == 'completed' ||
          newStatus == 'failed' ||
          newStatus == 'cancelled')) {
    cancelProgressionTimerForJob(id);
  }

  final updatedJob = job_store.updateJob(id, updatedFields);

  if (updatedJob == null) {
    // This implies job was not found by updateJob, which should be caught by findJobById earlier,
    // but as a safeguard or if updateJob itself can fail to find.
    return Response.notFound(
      jsonEncode({'error': 'Job with ID $id not found or failed to update'}),
      headers: {'content-type': 'application/json'},
    );
  }

  return Response.ok(
    jsonEncode({'data': updatedJob}),
    headers: {'content-type': 'application/json'},
  );
}

// Delete Job handler logic
Future<Response> deleteJobHandler(Request request, String id) async {
  final success = job_store.removeJob(id);
  if (!success) {
    return Response.notFound(
      jsonEncode({'error': 'Job with ID $id not found or already deleted'}),
      headers: {'content-type': 'application/json'},
    );
  }
  // Cancel any progression timer if the job is deleted
  cancelProgressionTimerForJob(id);
  return Response(
      HttpStatus.noContent); // 204 No Content for successful deletion
}
