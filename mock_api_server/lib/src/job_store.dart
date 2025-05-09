// ignore_for_file: avoid_print

import 'dart:io'; // For HttpStatus
import 'package:shelf/shelf.dart'; // For Response
import 'dart:convert'; // For jsonEncode
import 'package:mock_api_server/src/config.dart';

// --- Temporary In-Memory Job Storage ---
// TODO: This state should ideally be managed better, maybe injected.
// For now, keep it simple and mirror the global state from server.dart.

final List<Map<String, dynamic>> _jobs = [];

// --- Public API ---

/// Finds a job by its ID.
/// Throws a StateError if not found (consistent with firstWhere).
Map<String, dynamic> findJobById(String jobId) {
  try {
    return _jobs.firstWhere((job) => job['id'] == jobId);
  } on StateError {
    // Re-throw or handle as needed, maybe return null?
    // For now, maintain firstWhere behavior.
    if (verboseLoggingEnabled) {
      print('ERROR: Job with ID $jobId not found in JobStore.');
    }
    rethrow; // Or: return null;
  }
}

/// Updates the status and updated_at timestamp of a specific job.
/// Returns true if updated, false if job not found.
bool updateJobStatus(String jobId, String newStatus) {
  final jobIndex = _jobs.indexWhere((job) => job['id'] == jobId);
  if (jobIndex != -1) {
    _jobs[jobIndex]['status'] = newStatus;
    _jobs[jobIndex]['updated_at'] = DateTime.now().toUtc().toIso8601String();
    // Consider adding verbose logging here if needed
    if (verboseLoggingEnabled) {
      print('DEBUG JOBSTORE: Updated status for job $jobId to $newStatus');
    }
    return true;
  } else {
    // print('WARN: Attempted to update status for non-existent job ID: $jobId');
    if (verboseLoggingEnabled) {
      print(
          'WARN JOBSTORE: Attempted to update status for non-existent job ID: $jobId');
    }
    return false;
  }
}

/// Adds a new job to the store.
void addJob(Map<String, dynamic> newJob) {
  // Basic validation (optional)
  if (newJob['id'] == null) {
    //  print('ERROR: Attempted to add job without an ID.');
    if (verboseLoggingEnabled) {
      print('ERROR JOBSTORE: Attempted to add job without an ID.');
    }
    return; // Or throw?
  }
  // Prevent duplicates (optional)
  if (_jobs.any((job) => job['id'] == newJob['id'])) {
    // print('WARN: Attempted to add job with duplicate ID: ${newJob['id']}');
    if (verboseLoggingEnabled) {
      print(
          'WARN JOBSTORE: Attempted to add job with duplicate ID: ${newJob['id']}');
    }
    return; // Or update?
  }
  _jobs.add(newJob);
  if (verboseLoggingEnabled) {
    print('DEBUG JOBSTORE: Added job ${newJob['id']}');
  }
}

/// Removes a job from the store by ID.
/// Returns true if removed, false if not found.
bool removeJob(String jobId) {
  final initialLength = _jobs.length;
  _jobs.removeWhere((job) => job['id'] == jobId);
  final removed = _jobs.length < initialLength;
  if (removed && verboseLoggingEnabled) {
    print('DEBUG JOBSTORE: Removed job $jobId');
  }
  return removed;
}

/// Returns a list of all jobs.
List<Map<String, dynamic>> getAllJobs() {
  // Return a copy to prevent external modification of the internal list
  return List<Map<String, dynamic>>.from(_jobs);
}

/// Updates a job by its ID with the given fields.
/// Returns the updated job map if successful, null otherwise.
Map<String, dynamic>? updateJob(
    String jobId, Map<String, dynamic> updatedFields) {
  final jobIndex = _jobs.indexWhere((job) => job['id'] == jobId);
  if (jobIndex != -1) {
    updatedFields.forEach((key, value) {
      // Do not allow changing the ID via this method
      if (key != 'id') {
        _jobs[jobIndex][key] = value;
      }
    });
    _jobs[jobIndex]['updated_at'] = DateTime.now().toUtc().toIso8601String();
    if (verboseLoggingEnabled) {
      print(
          'DEBUG JOBSTORE: Updated job $jobId with fields: ${updatedFields.keys}');
    }
    return Map<String, dynamic>.from(_jobs[jobIndex]); // Return a copy
  }
  if (verboseLoggingEnabled) {
    print('WARN JOBSTORE: Attempted to update non-existent job ID: $jobId');
  }
  return null;
}

/// Finds a job index by ID. Returns -1 if not found.
int findJobIndexById(String jobId) {
  final index = _jobs.indexWhere((job) => job['id'] == jobId);
  if (index == -1 && verboseLoggingEnabled) {
    print('DEBUG JOBSTORE: Job index not found for ID: $jobId');
  }
  return index;
}

/// Updates a job found by index.
/// Be careful using this directly, prefer specific updaters like updateJobStatus.
bool updateJobByIndex(int index, Map<String, dynamic> updatedFields) {
  if (index < 0 || index >= _jobs.length) {
    //  print('ERROR: Invalid index provided to updateJobByIndex: $index');
    if (verboseLoggingEnabled) {
      print(
          'ERROR JOBSTORE: Invalid index provided to updateJobByIndex: $index');
    }
    return false;
  }
  // Merge updates - simple approach, overwrites existing keys
  // _jobs[index].addAll(updatedFields.cast<String, dynamic>()); // Avoid addAll due to type issues

  // Iterate and update key by key
  updatedFields.forEach((key, value) {
    _jobs[index][key] = value;
  });

  // Always update the timestamp
  _jobs[index]['updated_at'] = DateTime.now().toUtc().toIso8601String();
  if (verboseLoggingEnabled) {
    print(
        'DEBUG JOBSTORE: Updated job at index $index with fields: ${updatedFields.keys}');
  }
  return true;
}

/// Creates a standard NotFound response.
Response createNotFoundResponse(String entity, String id) {
  return Response(
    HttpStatus.notFound, // 404
    body: jsonEncode({'error': '$entity with ID $id not found'}),
    headers: {'content-type': 'application/json'},
  );
}
