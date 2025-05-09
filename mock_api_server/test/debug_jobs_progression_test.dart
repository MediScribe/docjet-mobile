// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:test/test.dart';

import 'test_helpers.dart'; // Import the helper

const String testApiKey = 'test-api-key';
const String dummyJwt = 'fake-jwt-token'; // For Authorization header

// Helper function to create a job and return its ID
Future<String> createTestJob(String baseUrl, String userId) async {
  final createUrl = Uri.parse('$baseUrl/api/v1/jobs');
  final createRequest = http.MultipartRequest('POST', createUrl)
    ..headers.addAll({
      'Authorization': 'Bearer $dummyJwt',
      'x-api-key': testApiKey,
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
    'x-api-key': testApiKey,
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
      expect(job['status'], 'submitted',
          reason: 'Job should have initial status submitted');
    });

    // Delete the job after each test to ensure isolation
    tearDown(() async {
      final deleteUrl = Uri.parse('$baseUrl/api/v1/jobs/$jobId');
      final headers = {
        'Authorization': 'Bearer $dummyJwt',
        'x-api-key': testApiKey,
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
        'x-api-key': testApiKey,
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
      expect(job['status'], 'completed',
          reason: 'Job should be completed immediately in fast test mode');

      // Act: Try starting again after completion
      final restartResponse = await http.post(startUrl, headers: headers);
      // Assert: Expect 200 OK with a specific message, not 400
      expect(restartResponse.statusCode, 200,
          reason: 'Should return 200 OK for already completed job');
      final restartBody = jsonDecode(restartResponse.body);
      expect(restartBody['message'],
          'Job $jobId is already completed. No action taken.',
          reason: 'Response message should indicate job already completed');
    });

    test('POST /stop?id={jobId} should stop status progression', () async {
      // This test needs to test actual progression stopping, so we use interval mode
      // but with a very small interval
      final startUrl = Uri.parse(
          '$baseUrl/api/v1/debug/jobs/start?id=$jobId&interval_seconds=0.2');
      final stopUrl = Uri.parse('$baseUrl/api/v1/debug/jobs/stop?id=$jobId');
      final headers = {
        'Authorization': 'Bearer $dummyJwt',
        'x-api-key': testApiKey,
      };

      // Act: Start progression
      final startResponse = await http.post(startUrl, headers: headers);
      expect(startResponse.statusCode, 200,
          reason: 'Setup: Failed to start progression');

      // Wait briefly for status change (with very fast interval)
      await Future.delayed(
          const Duration(milliseconds: 250)); // Just over 1 interval
      var jobBeforeStop = await getJob(baseUrl, jobId);
      final statusBeforeStop = jobBeforeStop['status'];
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
      expect(jobAfterStop['status'], statusBeforeStop,
          reason: 'Status should not change after stopping progression');
    });

    // --- Negative Path Tests ---

    test('POST /start without id should apply to all jobs and return 200',
        () async {
      // Arrange: Create another job so we have at least two
      final jobId2 = await createTestJob(baseUrl, 'progression-user-2');

      final url = Uri.parse(
          '$baseUrl/api/v1/debug/jobs/start?fast_test_mode=true'); // No id
      final headers = {
        'Authorization': 'Bearer $dummyJwt',
        'x-api-key': testApiKey,
      };

      // Act: Start progression for all jobs
      final response = await http.post(url, headers: headers);

      // Assert: Response indicates success
      expect(response.statusCode, 200);
      expect(response.body, contains('Start Progression applied to'));

      // Verify both jobs are completed
      var job1 = await getJob(baseUrl, jobId);
      var job2 = await getJob(baseUrl, jobId2);
      expect(job1['status'], 'completed');
      expect(job2['status'], 'completed');

      // Clean up the additional job
      final deleteUrl = Uri.parse('$baseUrl/api/v1/jobs/$jobId2');
      await http.delete(deleteUrl, headers: headers);
    });

    test(
        'POST /start (all jobs) without X-API-Key should return 200 and apply to all jobs',
        () async {
      // Arrange: Create another job so we have at least two
      final jobId2 = await createTestJob(baseUrl, 'progression-user-nokey');

      final url = Uri.parse(
          '$baseUrl/api/v1/debug/jobs/start?fast_test_mode=true'); // No id
      // INTENTIONALLY OMIT x-api-key
      final headers = {
        'Authorization': 'Bearer $dummyJwt',
      };

      // Act: Start progression for all jobs
      final response = await http.post(url, headers: headers);

      // Assert: Response indicates success (SHOULD BE 200, NOT 401)
      expect(response.statusCode, 200,
          reason:
              'Accessing debug endpoint without API key should now be allowed.');
      expect(response.body, contains('Start Progression applied to'),
          reason: 'Response should indicate action was applied.');

      // Verify both jobs are completed
      // To get jobs, we still need API key for the regular /jobs endpoint
      final getHeaders = {
        'Authorization': 'Bearer $dummyJwt',
        'x-api-key': testApiKey,
      };
      final getJob1Url = Uri.parse('$baseUrl/api/v1/jobs/$jobId');
      final getJob2Url = Uri.parse('$baseUrl/api/v1/jobs/$jobId2');

      final job1Response = await http.get(getJob1Url, headers: getHeaders);
      final job2Response = await http.get(getJob2Url, headers: getHeaders);

      expect(job1Response.statusCode, 200);
      expect(job2Response.statusCode, 200);

      var job1 = jsonDecode(job1Response.body)['data'] as Map<String, dynamic>;
      var job2 = jsonDecode(job2Response.body)['data'] as Map<String, dynamic>;

      expect(job1['status'], 'completed',
          reason:
              'Job 1 should be completed via debug endpoint without API key');
      expect(job2['status'], 'completed',
          reason:
              'Job 2 should be completed via debug endpoint without API key');

      // Clean up the additional job
      final deleteUrl = Uri.parse('$baseUrl/api/v1/jobs/$jobId2');
      await http.delete(deleteUrl,
          headers: getHeaders); // Use headers with API key for cleanup
    });

    test('All debug endpoints should be accessible without X-API-Key',
        () async {
      // Create a job for testing
      final testJobId = await createTestJob(baseUrl, 'api-key-exemption-test');

      // Standard headers WITH API key (for setup and verification only)
      final apiKeyHeaders = {
        'Authorization': 'Bearer $dummyJwt',
        'x-api-key': testApiKey,
      };

      // Headers WITHOUT API key (for actual test)
      final noApiKeyHeaders = {
        'Authorization': 'Bearer $dummyJwt',
      };

      // Setup - first progress a job to completed using API key
      final startUrl = Uri.parse(
          '$baseUrl/api/v1/debug/jobs/start?id=$testJobId&fast_test_mode=true');
      await http.post(startUrl, headers: apiKeyHeaders);

      // Verify job is completed
      var jobBefore = await getJob(baseUrl, testJobId);
      expect(jobBefore['status'], 'completed',
          reason: 'Setup: Job should be completed before exemption test');

      // Define all debug endpoints to test without API key
      final debugEndpoints = [
        // Test list endpoint (GET)
        {
          'method': 'GET',
          'url': '$baseUrl/api/v1/debug/jobs/list',
          'expectedStatus': 200,
          'expectedBodyContains': 'Debug endpoint:',
          'description': 'Debug list endpoint'
        },
        // Test stop endpoint (POST)
        {
          'method': 'POST',
          'url': '$baseUrl/api/v1/debug/jobs/stop?id=$testJobId',
          'expectedStatus': 200,
          'expectedBodyContains': 'no active progression timer was running',
          'description': 'Debug stop endpoint'
        },
        // Test reset endpoint (POST)
        {
          'method': 'POST',
          'url': '$baseUrl/api/v1/debug/jobs/reset?id=$testJobId',
          'expectedStatus': 200,
          'expectedBodyContains': 'reset to initial state',
          'description': 'Debug reset endpoint'
        },
        // Test start endpoint again (POST) - was already tested above but including for completeness
        {
          'method': 'POST',
          'url':
              '$baseUrl/api/v1/debug/jobs/start?id=$testJobId&interval_seconds=0.5',
          'expectedStatus': 200,
          'expectedBodyContains': 'progression started',
          'description': 'Debug start endpoint'
        }
      ];

      // Test each endpoint
      for (final endpoint in debugEndpoints) {
        final isPost = endpoint['method'] == 'POST';
        final response = isPost
            ? await http.post(Uri.parse(endpoint['url'] as String),
                headers: noApiKeyHeaders)
            : await http.get(Uri.parse(endpoint['url'] as String),
                headers: noApiKeyHeaders);

        // Verify response is successful
        expect(response.statusCode, endpoint['expectedStatus'],
            reason:
                '${endpoint['description']} should return 200 without API key, got ${response.statusCode}');
        expect(
            response.body, contains(endpoint['expectedBodyContains'] as String),
            reason:
                '${endpoint['description']} response should contain expected text');

        if (endpoint['url'].toString().contains('reset')) {
          // Verify reset worked
          var jobAfterReset = await getJob(baseUrl, testJobId);
          expect(jobAfterReset['status'], 'submitted',
              reason:
                  'Job should be reset to submitted when calling reset endpoint without API key');
        }
      }

      // Clean up
      final deleteUrl = Uri.parse('$baseUrl/api/v1/jobs/$testJobId');
      await http.delete(deleteUrl, headers: apiKeyHeaders);
    });

    test('POST /start with invalid interval should return 400', () async {
      final url = Uri.parse(
          '$baseUrl/api/v1/debug/jobs/start?id=$jobId&interval_seconds=invalid');
      final headers = {
        'Authorization': 'Bearer $dummyJwt',
        'x-api-key': testApiKey,
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
        'x-api-key': testApiKey,
      };
      final response = await http.post(url, headers: headers);
      expect(response.statusCode, 400);
      expect(response.body, contains('Invalid value for interval_seconds'));
    });

    test('POST /start with non-existent job ID should return 404', () async {
      const nonExistentJobId = 'ghost-job-id';
      final url =
          Uri.parse('$baseUrl/api/v1/debug/jobs/start?id=$nonExistentJobId');
      final headers = {
        'Authorization': 'Bearer $dummyJwt',
        'x-api-key': testApiKey,
      };
      final response = await http.post(url, headers: headers);
      expect(response.statusCode, 404);
      // Verify the new error message format
      final expectedErrorMessage = 'Job ID $nonExistentJobId not found.';
      final responseBody = jsonDecode(response.body);
      expect(responseBody['error'], expectedErrorMessage,
          reason: 'Error message should match the new format.');
      expect(responseBody.containsKey('available_jobs'), isTrue);
      expect(responseBody.containsKey('job_count'), isTrue);
    });

    test('POST /stop without id should apply to all jobs and return 200',
        () async {
      // Arrange: Create a couple of jobs and start their progression
      final jobId1 = await createTestJob(baseUrl, 'stop-all-user-1');
      final jobId2 = await createTestJob(baseUrl, 'stop-all-user-2');
      final headers = {
        'Authorization': 'Bearer $dummyJwt',
        'x-api-key': testApiKey,
      };

      // Start progression for both (non-fast mode, short interval to see change)
      final startUrl1 = Uri.parse(
          '$baseUrl/api/v1/debug/jobs/start?id=$jobId1&interval_seconds=0.5');
      final startUrl2 = Uri.parse(
          '$baseUrl/api/v1/debug/jobs/start?id=$jobId2&interval_seconds=0.5');
      await http.post(startUrl1, headers: headers);
      await http.post(startUrl2, headers: headers);

      // Allow some time for progression to start and not complete
      await Future.delayed(const Duration(milliseconds: 250));

      // Optional: Check they are progressing (not strictly needed for this test's main assertion)
      // final job1Prog = await getJob(baseUrl, jobId1);
      // final job2Prog = await getJob(baseUrl, jobId2);
      // expect(job1Prog['status'], isNot(equals('submitted')));
      // expect(job1Prog['status'], isNot(equals('completed')));

      final url = Uri.parse('$baseUrl/api/v1/debug/jobs/stop'); // No id

      // Act
      final response = await http.post(url, headers: headers);

      // Assert
      expect(response.statusCode, 200,
          reason: "Should return 200 for all-jobs stop");
      final responseBody = jsonDecode(response.body);
      // The number of jobs can vary if other tests didn't clean up perfectly or if the job_store isn't reset fully.
      // For now, let's check it applied to at least our 2 jobs, or more generally, contains the message structure.
      // A more robust test would fully reset the job store.
      expect(responseBody['message'], contains('Stop Progression applied to'),
          reason: "Response message mismatch");
      expect(responseBody['message'], endsWith('jobs.'),
          reason: "Response message mismatch");
      expect(responseBody['successful_applications'], greaterThanOrEqualTo(2),
          reason: "Should have attempted to stop at least 2 jobs");

      // Further assertions could involve checking job statuses after a delay to ensure they stopped progressing.
      // For example, record status now, wait, check status again.
      final job1AfterStop = await getJob(baseUrl, jobId1);
      final job2AfterStop = await getJob(baseUrl, jobId2);
      final status1AfterStop = job1AfterStop['status'];
      final status2AfterStop = job2AfterStop['status'];

      await Future.delayed(const Duration(milliseconds: 700)); // Longer delay

      final job1Final = await getJob(baseUrl, jobId1);
      final job2Final = await getJob(baseUrl, jobId2);
      expect(job1Final['status'], status1AfterStop,
          reason: "Job 1 should have stopped progressing");
      expect(job2Final['status'], status2AfterStop,
          reason: "Job 2 should have stopped progressing");

      // Clean up explicitly created jobs for this test
      final deleteUrl1 = Uri.parse('$baseUrl/api/v1/jobs/$jobId1');
      final deleteUrl2 = Uri.parse('$baseUrl/api/v1/jobs/$jobId2');
      await http.delete(deleteUrl1, headers: headers);
      await http.delete(deleteUrl2, headers: headers);
    });

    test('POST /stop with non-existent job ID should return 404', () async {
      const nonExistentJobId = 'ghost-job-id';
      final url =
          Uri.parse('$baseUrl/api/v1/debug/jobs/stop?id=$nonExistentJobId');
      final headers = {
        'Authorization': 'Bearer $dummyJwt',
        'x-api-key': testApiKey,
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
        'x-api-key': testApiKey,
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
        'x-api-key': testApiKey,
      };
      final startResponseSlow = await http.post(startUrlSlow, headers: headers);
      expect(startResponseSlow.statusCode, 200,
          reason: 'Failed to start slow progression');

      // Wait very briefly, status should still be 'submitted'
      await Future.delayed(const Duration(milliseconds: 100));
      var jobAfterSlowStart = await getJob(baseUrl, jobId);
      expect(jobAfterSlowStart['status'], 'submitted',
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
      expect(jobAfterFastStart['status'], 'completed',
          reason: 'Job should be completed by the overriding fast start');

      // Optional: Wait to ensure the slow timer didn't interfere later (difficult to guarantee without server logs/state inspection)
      // await Future.delayed(const Duration(seconds: 11));
      // var jobLater = await getJob(baseUrl, jobId);
      // expect(jobLater['status'], 'completed', reason: 'Job should remain completed');
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
        'x-api-key': testApiKey
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
      expect(jobAfterReset['status'], 'submitted',
          reason: 'Status should be reset');

      // Assert: Timer is stopped (status should not change anymore)
      await Future.delayed(const Duration(milliseconds: 300));
      jobAfterReset = await getJob(baseUrl, jobId);
      expect(jobAfterReset['status'], 'submitted',
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
        'x-api-key': testApiKey
      };
      final startResponse = await http.post(startUrl, headers: headers);
      expect(startResponse.statusCode, 200,
          reason: 'Setup: Failed to start/complete job');
      var jobBeforeReset = await getJob(baseUrl, jobId);
      expect(jobBeforeReset['status'], 'completed',
          reason: 'Setup: Job should be completed');

      // Act: Reset the completed job
      final resetResponse = await http.post(resetUrl, headers: headers);

      // Assert: Reset successful
      expect(resetResponse.statusCode, 200);

      // Assert: Status is reset
      var jobAfterReset = await getJob(baseUrl, jobId);
      expect(jobAfterReset['status'], 'submitted',
          reason: 'Status should be reset from completed');
    });

    test('POST /reset?id={jobId} for an idle job should reset status (noop)',
        () async {
      // Arrange: Job is created in setUp, but not started
      final resetUrl = Uri.parse('$baseUrl/api/v1/debug/jobs/reset?id=$jobId');
      final headers = {
        'Authorization': 'Bearer $dummyJwt',
        'x-api-key': testApiKey
      };
      var jobBeforeReset = await getJob(baseUrl, jobId);
      expect(jobBeforeReset['status'], 'submitted',
          reason: 'Setup: Job should be idle');

      // Act: Reset the idle job
      final resetResponse = await http.post(resetUrl, headers: headers);

      // Assert: Reset successful (even if it did nothing substantial)
      expect(resetResponse.statusCode, 200);

      // Assert: Status remains the same (submitted)
      var jobAfterReset = await getJob(baseUrl, jobId);
      expect(jobAfterReset['status'], 'submitted',
          reason: 'Status should remain submitted');
    });

    test('POST /reset without id should apply to all jobs and return 200',
        () async {
      // Arrange: Create a couple of jobs and start their progression
      final jobId1 = await createTestJob(baseUrl, 'reset-all-user-1');
      final jobId2 = await createTestJob(baseUrl, 'reset-all-user-2');
      final headers = {
        'Authorization': 'Bearer $dummyJwt',
        'x-api-key': testApiKey,
      };

      // Start progression for both (non-fast mode, short interval to see change)
      final startUrl1 = Uri.parse(
          '$baseUrl/api/v1/debug/jobs/start?id=$jobId1&interval_seconds=0.5');
      final startUrl2 = Uri.parse(
          '$baseUrl/api/v1/debug/jobs/start?id=$jobId2&interval_seconds=0.5');
      await http.post(startUrl1, headers: headers);
      await http.post(startUrl2, headers: headers);

      // Allow some time for progression to start and move past 'submitted'
      await Future.delayed(const Duration(milliseconds: 250));

      // Optional: Verify they have progressed from 'submitted'
      // final job1Prog = await getJob(baseUrl, jobId1);
      // expect(job1Prog['status'], isNot(equals('submitted')));

      final url = Uri.parse('$baseUrl/api/v1/debug/jobs/reset'); // No id

      // Act
      final response = await http.post(url, headers: headers);

      // Assert
      expect(response.statusCode, 200,
          reason: "Should return 200 for all-jobs reset");
      final responseBody = jsonDecode(response.body);
      expect(responseBody['message'], contains('Reset Progression applied to'),
          reason: "Response message mismatch for reset all");
      expect(responseBody['message'], endsWith('jobs.'),
          reason: "Response message mismatch for reset all");
      expect(responseBody['successful_applications'], greaterThanOrEqualTo(2),
          reason: "Should have attempted to reset at least 2 jobs");

      // Verify jobs are reset to 'submitted' and timers are stopped
      final job1AfterReset = await getJob(baseUrl, jobId1);
      final job2AfterReset = await getJob(baseUrl, jobId2);
      expect(job1AfterReset['status'], 'submitted',
          reason: "Job 1 should be reset to submitted");
      expect(job2AfterReset['status'], 'submitted',
          reason: "Job 2 should be reset to submitted");

      // Wait to ensure timers are indeed stopped
      await Future.delayed(const Duration(milliseconds: 700));
      final job1Final = await getJob(baseUrl, jobId1);
      final job2Final = await getJob(baseUrl, jobId2);
      expect(job1Final['status'], 'submitted',
          reason: "Job 1 should remain submitted (timer stopped)");
      expect(job2Final['status'], 'submitted',
          reason: "Job 2 should remain submitted (timer stopped)");

      // Clean up explicitly created jobs for this test
      final deleteUrl1 = Uri.parse('$baseUrl/api/v1/jobs/$jobId1');
      final deleteUrl2 = Uri.parse('$baseUrl/api/v1/jobs/$jobId2');
      await http.delete(deleteUrl1, headers: headers);
      await http.delete(deleteUrl2, headers: headers);
    });

    test('POST /reset with non-existent job ID should return 404', () async {
      const nonExistentJobId = 'ghost-job-id-reset';
      final url =
          Uri.parse('$baseUrl/api/v1/debug/jobs/reset?id=$nonExistentJobId');
      final headers = {
        'Authorization': 'Bearer $dummyJwt',
        'x-api-key': testApiKey
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
