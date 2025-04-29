// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:test/test.dart';

import 'test_helpers.dart'; // Import the helper

final String testApiKey = 'test-api-key';
final String dummyJwt = 'fake-jwt-token'; // For Authorization header

// Helper function to create a job and return its ID
Future<String> createTestJob(String baseUrl, String userId) async {
  final createUrl = Uri.parse('$baseUrl/api/v1/jobs');
  final createRequest = http.MultipartRequest('POST', createUrl)
    ..headers.addAll({
      'Authorization': 'Bearer $dummyJwt',
      'X-API-Key': testApiKey,
    })
    ..fields['user_id'] = userId
    ..files.add(http.MultipartFile.fromBytes('audio_file', [],
        filename: 'progression_test.mp3'));
  final createStreamedResponse = await createRequest.send();
  final createResponse = await http.Response.fromStream(createStreamedResponse);
  expect(createResponse.statusCode, 200,
      reason: 'Failed to create job for testing progression');
  final jsonResponse = jsonDecode(createResponse.body);
  return jsonResponse['data']['id'] as String;
}

// Helper to get job details
Future<Map<String, dynamic>> getJob(String baseUrl, String jobId) async {
  final getUrl = Uri.parse('$baseUrl/api/v1/jobs/$jobId');
  final getResponse = await http.get(getUrl, headers: {
    'Authorization': 'Bearer $dummyJwt',
    'X-API-Key': testApiKey,
  });
  expect(getResponse.statusCode, 200, reason: 'Failed to get job $jobId');
  return jsonDecode(getResponse.body)['data'] as Map<String, dynamic>;
}

void main() {
  Process? mockServerProcess;
  int mockServerPort = 0;
  late String baseUrl;

  setUpAll(() async {
    (mockServerProcess, mockServerPort) =
        await startMockServer('DebugJobsProgressionTest');
    if (mockServerProcess == null) {
      throw Exception(
          'Failed to start mock server for DebugJobsProgressionTest');
    }
    baseUrl = 'http://localhost:$mockServerPort';
  });

  tearDownAll(() async {
    await stopMockServer('DebugJobsProgressionTest', mockServerProcess);
  });

  group('/api/v1/debug/jobs/', () {
    late String jobId;

    // Create a job before each test in this group
    setUp(() async {
      jobId = await createTestJob(baseUrl, 'progression-user');
      // Ensure initial status is 'submitted' after creation
      final job = await getJob(baseUrl, jobId);
      expect(job['job_status'], 'submitted',
          reason: 'Job should have initial status submitted');
    });

    // Delete the job after each test to ensure isolation
    tearDown(() async {
      final deleteUrl = Uri.parse('$baseUrl/api/v1/jobs/$jobId');
      final headers = {
        'Authorization': 'Bearer $dummyJwt',
        'X-API-Key': testApiKey,
      };
      // Don't strictly need to check response, but good practice
      try {
        final response = await http.delete(deleteUrl, headers: headers);
        // Allow 404 if the test itself deleted the job
        if (response.statusCode != 200 && response.statusCode != 404) {
          print(
              'Warning: Failed to delete job $jobId in tearDown: ${response.statusCode}');
        }
      } catch (e) {
        print('Warning: Error deleting job $jobId in tearDown: $e');
      }
    });

    test('POST /start?id={jobId} should start status progression', () async {
      // Arrange
      final startUrl = Uri.parse(
          '$baseUrl/api/v1/debug/jobs/start?id=$jobId&fast_test_mode=true');
      final headers = {
        'Authorization': 'Bearer $dummyJwt', // Assuming debug needs auth
        'X-API-Key': testApiKey,
      };

      // Act: Start the progression
      final startResponse = await http.post(startUrl, headers: headers);

      // Assert: Initial start request is successful
      expect(startResponse.statusCode, 200,
          reason: 'Failed to start progression');
      expect(startResponse.body, contains('(fast mode)'),
          reason: 'Response should indicate fast mode completion');

      // With fast_test_mode=true, the job should already be completed
      var job = await getJob(baseUrl, jobId);
      expect(job['job_status'], 'completed',
          reason: 'Job should be completed immediately in fast test mode');

      // Act: Try starting again after completion
      final restartResponse = await http.post(startUrl, headers: headers);
      expect(restartResponse.statusCode, 400, // Or appropriate error
          reason: 'Should not be able to restart completed job progression');
    });

    test('POST /stop?id={jobId} should stop status progression', () async {
      // This test needs to test actual progression stopping, so we use interval mode
      // but with a very small interval
      final startUrl = Uri.parse(
          '$baseUrl/api/v1/debug/jobs/start?id=$jobId&interval_seconds=0.2');
      final stopUrl = Uri.parse('$baseUrl/api/v1/debug/jobs/stop?id=$jobId');
      final headers = {
        'Authorization': 'Bearer $dummyJwt',
        'X-API-Key': testApiKey,
      };

      // Act: Start progression
      final startResponse = await http.post(startUrl, headers: headers);
      expect(startResponse.statusCode, 200,
          reason: 'Setup: Failed to start progression');

      // Wait briefly for status change (with very fast interval)
      await Future.delayed(
          const Duration(milliseconds: 250)); // Just over 1 interval
      var jobBeforeStop = await getJob(baseUrl, jobId);
      final statusBeforeStop = jobBeforeStop['job_status'];
      expect(statusBeforeStop, isNot(equals('submitted')),
          reason: 'Setup: Status should have changed');
      expect(statusBeforeStop, isNot(equals('completed')),
          reason: 'Setup: Status should not be completed yet');

      // Act: Stop progression
      final stopResponse = await http.post(stopUrl, headers: headers);
      expect(stopResponse.statusCode, 200,
          reason: 'Failed to stop progression');
      expect(stopResponse.body, contains('Progression stopped for job $jobId'));

      // Act: Try stopping again
      final stopAgainResponse = await http.post(stopUrl, headers: headers);
      expect(stopAgainResponse.statusCode, 200,
          reason: 'Stopping again should be okay');

      // Assert: Status remains unchanged after stopping
      await Future.delayed(const Duration(milliseconds: 300));
      var jobAfterStop = await getJob(baseUrl, jobId);
      expect(jobAfterStop['job_status'], statusBeforeStop,
          reason: 'Status should not change after stopping progression');
    });

    // --- Negative Path Tests ---

    test('POST /start without id should return 400', () async {
      final url = Uri.parse('$baseUrl/api/v1/debug/jobs/start'); // No id
      final headers = {
        'Authorization': 'Bearer $dummyJwt',
        'X-API-Key': testApiKey,
      };
      final response = await http.post(url, headers: headers);
      expect(response.statusCode, 400);
      expect(response.body, contains('Missing required query parameter: id'));
    });

    test('POST /start with invalid interval should return 400', () async {
      final url = Uri.parse(
          '$baseUrl/api/v1/debug/jobs/start?id=$jobId&interval_seconds=invalid');
      final headers = {
        'Authorization': 'Bearer $dummyJwt',
        'X-API-Key': testApiKey,
      };
      final response = await http.post(url, headers: headers);
      expect(response.statusCode, 400);
      expect(response.body, contains('Invalid value for interval_seconds'));
    });

    test('POST /start with zero interval should return 400', () async {
      final url = Uri.parse(
          '$baseUrl/api/v1/debug/jobs/start?id=$jobId&interval_seconds=0');
      final headers = {
        'Authorization': 'Bearer $dummyJwt',
        'X-API-Key': testApiKey,
      };
      final response = await http.post(url, headers: headers);
      expect(response.statusCode, 400);
      expect(response.body, contains('Invalid value for interval_seconds'));
    });

    test('POST /start with non-existent job ID should return 404', () async {
      final nonExistentJobId = 'ghost-job-id';
      final url =
          Uri.parse('$baseUrl/api/v1/debug/jobs/start?id=$nonExistentJobId');
      final headers = {
        'Authorization': 'Bearer $dummyJwt',
        'X-API-Key': testApiKey,
      };
      final response = await http.post(url, headers: headers);
      expect(response.statusCode, 404);
      expect(
          response.body, contains('Job with ID $nonExistentJobId not found'));
    });

    test('POST /stop without id should return 400', () async {
      final url = Uri.parse('$baseUrl/api/v1/debug/jobs/stop'); // No id
      final headers = {
        'Authorization': 'Bearer $dummyJwt',
        'X-API-Key': testApiKey,
      };
      final response = await http.post(url, headers: headers);
      expect(response.statusCode, 400);
      expect(response.body, contains('Missing required query parameter: id'));
    });

    test('POST /stop with non-existent job ID should return 404', () async {
      final nonExistentJobId = 'ghost-job-id';
      final url =
          Uri.parse('$baseUrl/api/v1/debug/jobs/stop?id=$nonExistentJobId');
      final headers = {
        'Authorization': 'Bearer $dummyJwt',
        'X-API-Key': testApiKey,
      };
      final response = await http.post(url, headers: headers);
      expect(response.statusCode,
          404); // Stop should also return 404 if job never existed
      expect(
          response.body, contains('Job with ID $nonExistentJobId not found'));
    });

    test('POST /stop for existing job with no active timer should return 200',
        () async {
      // Job created in setUp, but progression not started
      final url = Uri.parse('$baseUrl/api/v1/debug/jobs/stop?id=$jobId');
      final headers = {
        'Authorization': 'Bearer $dummyJwt',
        'X-API-Key': testApiKey,
      };
      final response = await http.post(url, headers: headers);
      expect(response.statusCode, 200);
      expect(
          response.body, contains('no active progression timer was running'));
    });

    test('POST /start for an already progressing job should cancel old timer',
        () async {
      // Arrange: Start progression with a slow interval
      final startUrlSlow = Uri.parse(
          '$baseUrl/api/v1/debug/jobs/start?id=$jobId&interval_seconds=10');
      final headers = {
        'Authorization': 'Bearer $dummyJwt',
        'X-API-Key': testApiKey,
      };
      final startResponseSlow = await http.post(startUrlSlow, headers: headers);
      expect(startResponseSlow.statusCode, 200,
          reason: 'Failed to start slow progression');

      // Wait very briefly, status should still be 'submitted'
      await Future.delayed(const Duration(milliseconds: 100));
      var jobAfterSlowStart = await getJob(baseUrl, jobId);
      expect(jobAfterSlowStart['job_status'], 'submitted',
          reason: 'Status should not change yet');

      // Act: Start progression again, this time with fast mode
      final startUrlFast = Uri.parse(
          '$baseUrl/api/v1/debug/jobs/start?id=$jobId&fast_test_mode=true');
      final startResponseFast = await http.post(startUrlFast, headers: headers);

      // Assert: Second start request succeeds and completes the job (fast mode)
      expect(startResponseFast.statusCode, 200,
          reason: 'Failed to start fast progression over slow one');
      expect(startResponseFast.body, contains('(fast mode)'),
          reason: 'Response should indicate fast mode completion');

      // Assert: Job should be completed immediately due to the second (fast) start
      var jobAfterFastStart = await getJob(baseUrl, jobId);
      expect(jobAfterFastStart['job_status'], 'completed',
          reason: 'Job should be completed by the overriding fast start');

      // Optional: Wait to ensure the slow timer didn't interfere later (difficult to guarantee without server logs/state inspection)
      // await Future.delayed(const Duration(seconds: 11));
      // var jobLater = await getJob(baseUrl, jobId);
      // expect(jobLater['job_status'], 'completed', reason: 'Job should remain completed');
    });

    // --- Tests for /reset endpoint ---

    test(
        'POST /reset?id={jobId} should reset status to submitted and stop timer',
        () async {
      // Arrange: Start progression and let it run briefly
      final startUrl = Uri.parse(
          '$baseUrl/api/v1/debug/jobs/start?id=$jobId&interval_seconds=0.2');
      final resetUrl = Uri.parse('$baseUrl/api/v1/debug/jobs/reset?id=$jobId');
      final headers = {
        'Authorization': 'Bearer $dummyJwt',
        'X-API-Key': testApiKey
      };
      final startResponse = await http.post(startUrl, headers: headers);
      expect(startResponse.statusCode, 200,
          reason: 'Setup: Failed to start progression');
      await Future.delayed(
          const Duration(milliseconds: 250)); // Let it progress a bit

      // Act: Reset the job
      final resetResponse = await http.post(resetUrl, headers: headers);

      // Assert: Reset successful
      expect(resetResponse.statusCode, 200);
      expect(resetResponse.body, contains('Job $jobId reset to initial state'));

      // Assert: Status is reset
      var jobAfterReset = await getJob(baseUrl, jobId);
      expect(jobAfterReset['job_status'], 'submitted',
          reason: 'Status should be reset');

      // Assert: Timer is stopped (status should not change anymore)
      await Future.delayed(const Duration(milliseconds: 300));
      jobAfterReset = await getJob(baseUrl, jobId);
      expect(jobAfterReset['job_status'], 'submitted',
          reason: 'Status should remain reset');
    });

    test('POST /reset?id={jobId} for a completed job should reset status',
        () async {
      // Arrange: Start progression in fast mode to complete it
      final startUrl = Uri.parse(
          '$baseUrl/api/v1/debug/jobs/start?id=$jobId&fast_test_mode=true');
      final resetUrl = Uri.parse('$baseUrl/api/v1/debug/jobs/reset?id=$jobId');
      final headers = {
        'Authorization': 'Bearer $dummyJwt',
        'X-API-Key': testApiKey
      };
      final startResponse = await http.post(startUrl, headers: headers);
      expect(startResponse.statusCode, 200,
          reason: 'Setup: Failed to start/complete job');
      var jobBeforeReset = await getJob(baseUrl, jobId);
      expect(jobBeforeReset['job_status'], 'completed',
          reason: 'Setup: Job should be completed');

      // Act: Reset the completed job
      final resetResponse = await http.post(resetUrl, headers: headers);

      // Assert: Reset successful
      expect(resetResponse.statusCode, 200);

      // Assert: Status is reset
      var jobAfterReset = await getJob(baseUrl, jobId);
      expect(jobAfterReset['job_status'], 'submitted',
          reason: 'Status should be reset from completed');
    });

    test('POST /reset?id={jobId} for an idle job should reset status (noop)',
        () async {
      // Arrange: Job is created in setUp, but not started
      final resetUrl = Uri.parse('$baseUrl/api/v1/debug/jobs/reset?id=$jobId');
      final headers = {
        'Authorization': 'Bearer $dummyJwt',
        'X-API-Key': testApiKey
      };
      var jobBeforeReset = await getJob(baseUrl, jobId);
      expect(jobBeforeReset['job_status'], 'submitted',
          reason: 'Setup: Job should be idle');

      // Act: Reset the idle job
      final resetResponse = await http.post(resetUrl, headers: headers);

      // Assert: Reset successful (even if it did nothing substantial)
      expect(resetResponse.statusCode, 200);

      // Assert: Status remains the same (submitted)
      var jobAfterReset = await getJob(baseUrl, jobId);
      expect(jobAfterReset['job_status'], 'submitted',
          reason: 'Status should remain submitted');
    });

    test('POST /reset without id should return 400', () async {
      final url = Uri.parse('$baseUrl/api/v1/debug/jobs/reset'); // No id
      final headers = {
        'Authorization': 'Bearer $dummyJwt',
        'X-API-Key': testApiKey
      };
      final response = await http.post(url, headers: headers);
      expect(response.statusCode, 400);
      expect(response.body, contains('Missing required query parameter: id'));
    });

    test('POST /reset with non-existent job ID should return 404', () async {
      final nonExistentJobId = 'ghost-job-id-reset';
      final url =
          Uri.parse('$baseUrl/api/v1/debug/jobs/reset?id=$nonExistentJobId');
      final headers = {
        'Authorization': 'Bearer $dummyJwt',
        'X-API-Key': testApiKey
      };
      final response = await http.post(url, headers: headers);
      expect(response.statusCode, 404);
      expect(
          response.body, contains('Job with ID $nonExistentJobId not found'));
    });

    // TODO: Add test for POST /reset?id={jobId} in Cycle 2

    // TODO: Add tests for unauthorized access (missing/wrong API key/JWT)
    // TODO: Add test for starting progression on an already progressing job (covered implicitly? Add explicit?)
  });
}
