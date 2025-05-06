// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:test/test.dart';

import 'test_helpers.dart'; // Import the helper

// Helper function to create a job and return its ID
Future<String> createTestJob(String baseUrl, String userId) async {
  final createUrl = Uri.parse('$baseUrl/api/v1/jobs');
  final createRequest = http.MultipartRequest('POST', createUrl)
    ..headers.addAll({
      'Authorization': 'Bearer fake-jwt-token',
      'x-api-key': 'test-api-key',
    })
    ..fields['user_id'] = userId
    ..files.add(http.MultipartFile.fromBytes('audio_file', [],
        filename: 'debug_list_test.mp3'));
  final createStreamedResponse = await createRequest.send();
  final createResponse = await http.Response.fromStream(createStreamedResponse);
  expect(createResponse.statusCode, 200,
      reason: 'Failed to create job for testing list endpoint');
  final jsonResponse = jsonDecode(createResponse.body);
  return jsonResponse['data']['id'] as String;
}

void main() {
  Process? mockServerProcess;
  int mockServerPort = 0;
  late String baseUrl;

  setUpAll(() async {
    (mockServerProcess, mockServerPort) =
        await startMockServer('DebugJobsListTest');
    if (mockServerProcess == null) {
      throw Exception('Failed to start mock server for DebugJobsListTest');
    }
    baseUrl = 'http://localhost:$mockServerPort';
    print('Mock server started at $baseUrl');
  });

  tearDownAll(() async {
    await stopMockServer('DebugJobsListTest', mockServerProcess);
  });

  group('/debug/jobs/list', () {
    late String jobId1;
    late String jobId2;

    // Create test jobs before running the tests
    setUp(() async {
      // Create multiple jobs to test the list endpoint
      jobId1 = await createTestJob(baseUrl, 'list-test-user-1');
      jobId2 = await createTestJob(baseUrl, 'list-test-user-2');
      print('Created test jobs: $jobId1, $jobId2');
    });

    // Clean up after tests
    tearDown(() async {
      // Delete the jobs after each test
      final headers = {
        'Authorization': 'Bearer fake-jwt-token',
        'x-api-key': 'test-api-key',
      };

      final deleteUrl1 = Uri.parse('$baseUrl/api/v1/jobs/$jobId1');
      final deleteUrl2 = Uri.parse('$baseUrl/api/v1/jobs/$jobId2');

      try {
        await http.delete(deleteUrl1, headers: headers);
        await http.delete(deleteUrl2, headers: headers);
        print('Deleted test jobs: $jobId1, $jobId2');
      } catch (e) {
        print('Warning: Error deleting jobs in tearDown: $e');
      }
    });

    test(
        'GET /debug/jobs/list should return all jobs successfully even without authentication headers',
        () async {
      // Arrange
      final url = Uri.parse('$baseUrl/api/v1/debug/jobs/list');

      // Act: Make request WITHOUT authentication headers
      final response = await http.get(url);

      // Assert: Should now return 200 OK as debug endpoints are exempt from API key
      expect(response.statusCode, 200,
          reason:
              'Debug list endpoint should now be accessible without API key and return 200');

      // Assert: Basic content check
      final jsonResponse = jsonDecode(response.body);
      expect(jsonResponse['jobs'], isA<List>(),
          reason: 'Response jobs should be a list');

      // Check response structure
      expect(jsonResponse, contains('jobs'),
          reason: 'Response should contain jobs key');
      expect(jsonResponse, contains('count'),
          reason: 'Response should contain count key');
      expect(jsonResponse, contains('message'),
          reason: 'Response should contain message key');

      // Check that our test jobs are in the list (created in setUp)
      final jobs = jsonResponse['jobs'] as List;
      final jobIds = jobs.map((job) => job['id']).toList();
      expect(jobIds, contains(jobId1),
          reason: 'Response should contain jobId1 (from setUp)');
      expect(jobIds, contains(jobId2),
          reason: 'Response should contain jobId2 (from setUp)');

      // Count should match the number of jobs returned
      expect(jsonResponse['count'], equals(jobs.length),
          reason: 'Count should match the number of jobs returned');
    });

    test('GET /api/v1/debug/jobs/list should work with auth headers', () async {
      // Arrange
      final url = Uri.parse('$baseUrl/api/v1/debug/jobs/list');
      final headers = {
        'Authorization': 'Bearer fake-jwt-token',
        'x-api-key': 'test-api-key',
      };

      // Act: Make request WITH authentication headers
      final response = await http.get(url, headers: headers);

      // Assert: Should return 200 OK
      expect(response.statusCode, 200,
          reason: 'Should return 200 status code with auth headers');

      // Basic content check
      final jsonResponse = jsonDecode(response.body);
      expect(jsonResponse['jobs'], isA<List>(),
          reason: 'Response jobs should be a list');

      // Check response structure
      expect(jsonResponse, contains('jobs'),
          reason: 'Response should contain jobs key');
      expect(jsonResponse, contains('count'),
          reason: 'Response should contain count key');
      expect(jsonResponse, contains('message'),
          reason: 'Response should contain message key');

      // Check that our test jobs are in the list
      final jobs = jsonResponse['jobs'] as List;
      final jobIds = jobs.map((job) => job['id']).toList();
      expect(jobIds, contains(jobId1),
          reason: 'Response should contain jobId1');
      expect(jobIds, contains(jobId2),
          reason: 'Response should contain jobId2');

      // Count should match the number of jobs returned
      expect(jsonResponse['count'], equals(jobs.length),
          reason: 'Count should match the number of jobs returned');
    });

    test('GET /debug/jobs/list should handle empty job store', () async {
      // Arrange: Delete all test jobs first to ensure empty state
      final headers = {
        'Authorization': 'Bearer fake-jwt-token',
        'x-api-key': 'test-api-key',
      };

      final deleteUrl1 = Uri.parse('$baseUrl/api/v1/jobs/$jobId1');
      final deleteUrl2 = Uri.parse('$baseUrl/api/v1/jobs/$jobId2');

      await http.delete(deleteUrl1, headers: headers);
      await http.delete(deleteUrl2, headers: headers);

      // Act: Get the jobs list
      final url = Uri.parse('$baseUrl/api/v1/debug/jobs/list');
      final response = await http.get(url, headers: headers);

      // Assert: Should still return 200 OK
      expect(response.statusCode, 200,
          reason: 'Should return 200 status code with empty job store');

      // Check empty list
      final jsonResponse = jsonDecode(response.body);
      expect(jsonResponse['jobs'], isEmpty,
          reason: 'Jobs list should be empty');
      expect(jsonResponse['count'], equals(0), reason: 'Count should be 0');
    });

    test(
        'POST /api/v1/debug/jobs/start with non-existent job ID should return 404 with available jobs',
        () async {
      // Arrange
      const nonExistentJobId = 'job-that-does-not-exist';
      final url =
          Uri.parse('$baseUrl/api/v1/debug/jobs/start?id=$nonExistentJobId');
      final headers = {
        'Authorization': 'Bearer fake-jwt-token',
        'x-api-key': 'test-api-key',
      };

      // Act: Try to start progression for a non-existent job
      final response = await http.post(url, headers: headers);

      // Assert: Should return 404 Not Found
      expect(response.statusCode, 404,
          reason: 'Should return 404 status code for non-existent job');

      // Check response includes available jobs
      final jsonResponse = jsonDecode(response.body);
      expect(jsonResponse['error'], contains('not found'),
          reason: 'Response should include error message');
      expect(jsonResponse.containsKey('available_jobs'), isTrue,
          reason: 'Response should include available_jobs field');
      expect(jsonResponse.containsKey('job_count'), isTrue,
          reason: 'Response should include job_count field');

      // Make sure our test jobs are in the available_jobs list
      final availableJobsListFromJson = jsonResponse['available_jobs'] as List;
      // availableJobsListFromJson is a list of job ID strings, e.g., ["id1", "id2"]
      // So, it already is the list of jobIds.
      final jobIds = List<String>.from(availableJobsListFromJson);

      expect(jobIds, contains(jobId1),
          reason: 'Available jobs should include jobId1');
      expect(jobIds, contains(jobId2),
          reason: 'Available jobs should include jobId2');
      expect(jsonResponse['job_count'], equals(jobIds.length),
          reason: 'Job count should match the number of available jobs');
    });
  });
}
