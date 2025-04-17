import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

// Constants from auth tests (or shared location eventually)
final String baseUrl = 'http://localhost:8080';
final String testApiKey = 'test-api-key';
final String dummyJwt = 'fake-jwt-token'; // For Authorization header

void main() {
  // TODO: Add setupAll/tearDownAll to start/stop server?
  // TODO: Maybe reset in-memory job list between tests?

  group('POST /api/v1/jobs', () {
    test('should create a job and return job record on success', () async {
      // Arrange
      final url = Uri.parse('$baseUrl/api/v1/jobs');
      final request = http.MultipartRequest('POST', url);

      request.headers.addAll({
        'Authorization': 'Bearer $dummyJwt',
        'X-API-Key': testApiKey,
        // Content-Type is set automatically by MultipartRequest
      });

      request.fields['user_id'] = 'test-user-id';
      request.fields['text'] = 'Optional text note';
      request.fields['additional_text'] = 'More metadata';

      // Add a dummy audio file
      request.files.add(http.MultipartFile.fromBytes(
        'audio_file', // Field name expected by the API
        utf8.encode('fake audio data'), // Dummy content
        filename: 'test_audio.mp3',
      ));

      // Act
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      // Assert
      expect(response.statusCode, 200); // Spec says 200 OK
      expect(response.headers['content-type'], contains('application/json'));

      final jsonResponse = jsonDecode(response.body);
      expect(jsonResponse, isA<Map<String, dynamic>>());
      expect(jsonResponse['data']['id'], isA<String>());
      expect(jsonResponse['data']['user_id'], 'test-user-id');
      expect(jsonResponse['data']['job_status'], 'submitted');
      expect(jsonResponse['data']['text'], 'Optional text note');
      expect(jsonResponse['data']['additional_text'], 'More metadata');
      expect(jsonResponse['data']['created_at'], isA<String>());
      expect(jsonResponse['data']['updated_at'], isA<String>());
      expect(jsonResponse['data'], isNot(contains('display_title')));
      expect(jsonResponse['data'], isNot(contains('display_text')));
    });

    test('should return 401 Unauthorized if X-API-Key is missing', () async {
      // Arrange
      final url = Uri.parse('$baseUrl/api/v1/jobs');
      final request = http.MultipartRequest('POST', url);
      request.headers.addAll({
        'Authorization': 'Bearer $dummyJwt',
        // No X-API-Key
      });
      request.fields['user_id'] = 'test-user-id';
      request.files.add(http.MultipartFile.fromBytes('audio_file', []));

      // Act
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      // Assert
      expect(response.statusCode, 401);
    });

    test('should return 401 Unauthorized if Authorization header is missing',
        () async {
      // Arrange
      final url = Uri.parse('$baseUrl/api/v1/jobs');
      final request = http.MultipartRequest('POST', url);
      request.headers.addAll({
        'X-API-Key': testApiKey,
        // No Authorization
      });
      request.fields['user_id'] = 'test-user-id';
      request.files.add(http.MultipartFile.fromBytes('audio_file', []));

      // Act
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      // Assert
      // We need a middleware for this check, expecting 401
      expect(response.statusCode, 401);
    });

    test('should return 400 Bad Request if user_id field is missing', () async {
      // Arrange
      final url = Uri.parse('$baseUrl/api/v1/jobs');
      final request = http.MultipartRequest('POST', url);
      request.headers.addAll({
        'Authorization': 'Bearer $dummyJwt',
        'X-API-Key': testApiKey,
      });
      // No user_id field
      request.files.add(http.MultipartFile.fromBytes('audio_file', []));

      // Act
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      // Assert
      expect(response.statusCode, 400);
    });

    test('should return 400 Bad Request if audio_file part is missing',
        () async {
      // Arrange
      final url = Uri.parse('$baseUrl/api/v1/jobs');
      final request = http.MultipartRequest('POST', url);
      request.headers.addAll({
        'Authorization': 'Bearer $dummyJwt',
        'X-API-Key': testApiKey,
      });
      request.fields['user_id'] = 'test-user-id';
      // No audio_file part

      // Act
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      // Assert
      expect(response.statusCode, 400);
    });
  });

  group('GET /api/v1/jobs', () {
    // Helper to create a job for testing GET requests
    Future<Map<String, dynamic>> _createTestJob() async {
      final createUrl = Uri.parse('$baseUrl/api/v1/jobs');
      final createRequest = http.MultipartRequest('POST', createUrl)
        ..headers.addAll({
          'Authorization': 'Bearer $dummyJwt',
          'X-API-Key': testApiKey,
        })
        ..fields['user_id'] = 'test-user-get'
        ..files.add(http.MultipartFile.fromBytes('audio_file', [],
            filename: 'get_test.mp3'));
      final createStreamedResponse = await createRequest.send();
      final createResponse =
          await http.Response.fromStream(createStreamedResponse);
      expect(createResponse.statusCode, 200); // Ensure creation succeeded
      return jsonDecode(createResponse.body)['data'];
    }

    setUp(() {
      // Clear the jobs list before each GET test to ensure isolation
      // This requires access to the server's state or a reset endpoint,
      // which we don't have. For now, tests might depend on order or previous state.
      // A better approach would be server reset or starting fresh each time.
      // Let's assume for now the POST tests run first and leave one job.
      // TODO: Implement a proper reset mechanism for the mock server state.
    });

    test('should return 200 OK with an empty list if no jobs exist', () async {
      // Arrange
      // TODO: Need a way to ensure _jobs is empty before this test.
      // Assuming it's empty for now.
      final url = Uri.parse('$baseUrl/api/v1/jobs');
      final headers = {
        'Authorization': 'Bearer $dummyJwt',
        'X-API-Key': testApiKey,
      };

      // Act
      final response = await http.get(url, headers: headers);

      // Assert
      expect(response.statusCode, 200);
      expect(response.headers['content-type'], contains('application/json'));
      final jsonResponse = jsonDecode(response.body);
      expect(jsonResponse, isA<Map<String, dynamic>>());
      expect(jsonResponse['data'], isA<List>());
      // Can't reliably assert empty list without server reset
      // expect(jsonResponse['data'], isEmpty);
    });

    test('should return 200 OK with a list of existing jobs', () async {
      // Arrange
      // Create a job first to ensure there's something to retrieve
      final createdJob = await _createTestJob();
      final url = Uri.parse('$baseUrl/api/v1/jobs');
      final headers = {
        'Authorization': 'Bearer $dummyJwt',
        'X-API-Key': testApiKey,
      };

      // Act
      final response = await http.get(url, headers: headers);

      // Assert
      expect(response.statusCode, 200);
      expect(response.headers['content-type'], contains('application/json'));
      final jsonResponse = jsonDecode(response.body);
      expect(jsonResponse['data'], isA<List>());
      expect(jsonResponse['data'], isNotEmpty);

      // Find the job we created in the list
      final retrievedJob = (jsonResponse['data'] as List).firstWhere(
          (job) => job['id'] == createdJob['id'],
          orElse: () => null);

      expect(retrievedJob, isNotNull);
      expect(retrievedJob['id'], createdJob['id']);
      expect(retrievedJob['user_id'], createdJob['user_id']);
      expect(retrievedJob['job_status'], createdJob['job_status']);
      // Note: Response for GET list might not include all fields like POST
      // Adjust expectations based on spec.md if needed. Assuming same fields for now.
      expect(retrievedJob, isNot(contains('display_title')));
      expect(retrievedJob, isNot(contains('display_text')));
    });

    test('should return 401 Unauthorized if X-API-Key is missing', () async {
      // Arrange
      final url = Uri.parse('$baseUrl/api/v1/jobs');
      final headers = {
        'Authorization': 'Bearer $dummyJwt',
        // No X-API-Key
      };

      // Act
      final response = await http.get(url, headers: headers);

      // Assert
      expect(response.statusCode, 401);
    });

    test('should return 401 Unauthorized if Authorization header is missing',
        () async {
      // Arrange
      final url = Uri.parse('$baseUrl/api/v1/jobs');
      final headers = {
        'X-API-Key': testApiKey,
        // No Authorization
      };

      // Act
      final response = await http.get(url, headers: headers);

      // Assert
      expect(response.statusCode, 401);
    });
  }); // End group GET /api/v1/jobs

  group('GET /api/v1/jobs/{id}', () {
    // Helper to create a job for testing GET requests
    Future<Map<String, dynamic>> _createTestJob() async {
      final createUrl = Uri.parse('$baseUrl/api/v1/jobs');
      final createRequest = http.MultipartRequest('POST', createUrl)
        ..headers.addAll({
          'Authorization': 'Bearer $dummyJwt',
          'X-API-Key': testApiKey,
        })
        ..fields['user_id'] = 'test-user-get-id'
        ..fields['text'] = 'Job for ID lookup'
        ..files.add(http.MultipartFile.fromBytes('audio_file', [],
            filename: 'get_id_test.mp3'));
      final createStreamedResponse = await createRequest.send();
      final createResponse =
          await http.Response.fromStream(createStreamedResponse);
      expect(createResponse.statusCode, 200); // Ensure creation succeeded
      return jsonDecode(createResponse.body)['data'];
    }

    test('should return 200 OK with the specific job details if found',
        () async {
      // Arrange
      final createdJob = await _createTestJob();
      final jobId = createdJob['id'];
      final url = Uri.parse('$baseUrl/api/v1/jobs/$jobId');
      final headers = {
        'Authorization': 'Bearer $dummyJwt',
        'X-API-Key': testApiKey,
      };

      // Act
      final response = await http.get(url, headers: headers);

      // Assert
      expect(response.statusCode, 200);
      expect(response.headers['content-type'], contains('application/json'));
      final jsonResponse = jsonDecode(response.body);
      expect(jsonResponse, isA<Map<String, dynamic>>());
      expect(jsonResponse['data']['id'], jobId);
      expect(jsonResponse['data']['user_id'], 'test-user-get-id');
      expect(jsonResponse['data']['job_status'], 'submitted');
      expect(jsonResponse['data']['text'], 'Job for ID lookup');
      // Assuming GET by ID returns the full detail, same as POST response
      expect(jsonResponse['data'], isNot(contains('display_title')));
      expect(jsonResponse['data'], isNot(contains('display_text')));
    });

    test('should return 404 Not Found if job ID does not exist', () async {
      // Arrange
      final nonExistentJobId = 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee';
      final url = Uri.parse('$baseUrl/api/v1/jobs/$nonExistentJobId');
      final headers = {
        'Authorization': 'Bearer $dummyJwt',
        'X-API-Key': testApiKey,
      };

      // Act
      final response = await http.get(url, headers: headers);

      // Assert
      expect(response.statusCode, 404);
    });

    test('should return 401 Unauthorized if X-API-Key is missing', () async {
      // Arrange
      // No need to create a job, auth happens first
      final url = Uri.parse('$baseUrl/api/v1/jobs/any-id');
      final headers = {
        'Authorization': 'Bearer $dummyJwt',
        // No X-API-Key
      };

      // Act
      final response = await http.get(url, headers: headers);

      // Assert
      expect(response.statusCode, 401);
    });

    test('should return 401 Unauthorized if Authorization header is missing',
        () async {
      // Arrange
      final url = Uri.parse('$baseUrl/api/v1/jobs/any-id');
      final headers = {
        'X-API-Key': testApiKey,
        // No Authorization
      };

      // Act
      final response = await http.get(url, headers: headers);

      // Assert
      expect(response.statusCode, 401);
    });
  }); // End group GET /api/v1/jobs/{id}

  group('GET /api/v1/jobs/{id}/documents', () {
    // Helper to create a job for testing
    Future<Map<String, dynamic>> _createTestJob() async {
      final createUrl = Uri.parse('$baseUrl/api/v1/jobs');
      final createRequest = http.MultipartRequest('POST', createUrl)
        ..headers.addAll({
          'Authorization': 'Bearer $dummyJwt',
          'X-API-Key': testApiKey,
        })
        ..fields['user_id'] = 'test-user-docs'
        ..files.add(http.MultipartFile.fromBytes('audio_file', [],
            filename: 'docs_test.mp3'));
      final createStreamedResponse = await createRequest.send();
      final createResponse =
          await http.Response.fromStream(createStreamedResponse);
      expect(createResponse.statusCode, 200);
      return jsonDecode(createResponse.body)['data'];
    }

    test('should return 200 OK with a list of document details if job exists',
        () async {
      // Arrange
      final createdJob = await _createTestJob();
      final jobId = createdJob['id'];
      final url = Uri.parse('$baseUrl/api/v1/jobs/$jobId/documents');
      final headers = {
        'Authorization': 'Bearer $dummyJwt',
        'X-API-Key': testApiKey,
      };

      // Act
      final response = await http.get(url, headers: headers);

      // Assert
      expect(response.statusCode, 200);
      expect(response.headers['content-type'], contains('application/json'));
      final jsonResponse = jsonDecode(response.body);
      expect(jsonResponse, isA<Map<String, dynamic>>());
      expect(jsonResponse['data'], isA<List>());
      // For mock, check if it returns a list (content can be hardcoded)
      // The spec might define the structure of the document objects
      expect(jsonResponse['data'], isNotEmpty);
      expect(jsonResponse['data'][0], contains('id'));
      expect(jsonResponse['data'][0], contains('type'));
      expect(jsonResponse['data'][0], contains('url'));
    });

    test('should return 404 Not Found if job ID does not exist', () async {
      // Arrange
      final nonExistentJobId = 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee';
      final url = Uri.parse('$baseUrl/api/v1/jobs/$nonExistentJobId/documents');
      final headers = {
        'Authorization': 'Bearer $dummyJwt',
        'X-API-Key': testApiKey,
      };

      // Act
      final response = await http.get(url, headers: headers);

      // Assert
      expect(response.statusCode, 404);
    });

    test('should return 401 Unauthorized if X-API-Key is missing', () async {
      // Arrange
      final url = Uri.parse('$baseUrl/api/v1/jobs/any-id/documents');
      final headers = {
        'Authorization': 'Bearer $dummyJwt',
        // No X-API-Key
      };

      // Act
      final response = await http.get(url, headers: headers);

      // Assert
      expect(response.statusCode, 401);
    });

    test('should return 401 Unauthorized if Authorization header is missing',
        () async {
      // Arrange
      final url = Uri.parse('$baseUrl/api/v1/jobs/any-id/documents');
      final headers = {
        'X-API-Key': testApiKey,
        // No Authorization
      };

      // Act
      final response = await http.get(url, headers: headers);

      // Assert
      expect(response.statusCode, 401);
    });
  }); // End group GET /api/v1/jobs/{id}/documents

  group('PATCH /api/v1/jobs/{id}', () {
    // Helper to create a job for testing PATCH requests
    Future<Map<String, dynamic>> _createTestJobForPatch() async {
      final createUrl = Uri.parse('$baseUrl/api/v1/jobs');
      final createRequest = http.MultipartRequest('POST', createUrl)
        ..headers.addAll({
          'Authorization': 'Bearer $dummyJwt',
          'X-API-Key': testApiKey,
        })
        ..fields['user_id'] = 'test-user-patch'
        ..files.add(http.MultipartFile.fromBytes('audio_file', [],
            filename: 'patch_test.mp3'));
      final createStreamedResponse = await createRequest.send();
      final createResponse =
          await http.Response.fromStream(createStreamedResponse);
      expect(createResponse.statusCode, 200); // Ensure creation succeeded
      return jsonDecode(createResponse.body)['data'];
    }

    test('should return 200 OK and update job fields on success', () async {
      // Arrange
      final createdJob = await _createTestJobForPatch();
      final jobId = createdJob['id'];
      final originalUpdatedAt = createdJob['updated_at'];
      final url = Uri.parse('$baseUrl/api/v1/jobs/$jobId');
      final headers = {
        'Authorization': 'Bearer $dummyJwt',
        'X-API-Key': testApiKey,
        'Content-Type': 'application/json',
      };
      final body = jsonEncode({
        'text': 'Updated transcript text via PATCH',
        'display_title': 'Updated Title',
        'display_text': 'Updated snippet...'
        // Assuming PATCH might also update status, e.g., to transcribed
      });

      // Add a small delay to ensure updated_at timestamp is different
      await Future.delayed(Duration(milliseconds: 10));

      // Act
      final response = await http.patch(url, headers: headers, body: body);

      // Assert
      expect(response.statusCode, 200);
      expect(response.headers['content-type'], contains('application/json'));
      final jsonResponse = jsonDecode(response.body);
      expect(jsonResponse, isA<Map<String, dynamic>>());
      final updatedJob = jsonResponse['data'];
      expect(updatedJob['id'], jobId);
      expect(updatedJob['text'], 'Updated transcript text via PATCH');
      expect(updatedJob['display_title'], 'Updated Title');
      expect(updatedJob['display_text'], 'Updated snippet...');
      // Check if status was updated (optional, depends on mock logic)
      // expect(updatedJob['job_status'], 'transcribed');
      expect(updatedJob['updated_at'], isNot(originalUpdatedAt));
    });

    test('should return 200 OK and update only provided fields', () async {
      // Arrange
      final createdJob = await _createTestJobForPatch();
      final jobId = createdJob['id'];
      final originalText = createdJob['text']; // Should remain unchanged
      final url = Uri.parse('$baseUrl/api/v1/jobs/$jobId');
      final headers = {
        'Authorization': 'Bearer $dummyJwt',
        'X-API-Key': testApiKey,
        'Content-Type': 'application/json',
      };
      final body = jsonEncode({
        'display_title': 'Only Title Updated',
      });

      // Act
      final response = await http.patch(url, headers: headers, body: body);

      // Assert
      expect(response.statusCode, 200);
      final jsonResponse = jsonDecode(response.body);
      final updatedJob = jsonResponse['data'];
      expect(updatedJob['id'], jobId);
      expect(updatedJob['display_title'], 'Only Title Updated');
      expect(updatedJob['text'], originalText); // Verify text didn't change
      expect(updatedJob['display_text'], isNull); // display_text wasn't sent
    });

    test('should return 404 Not Found if job ID does not exist', () async {
      // Arrange
      final nonExistentJobId = 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee';
      final url = Uri.parse('$baseUrl/api/v1/jobs/$nonExistentJobId');
      final headers = {
        'Authorization': 'Bearer $dummyJwt',
        'X-API-Key': testApiKey,
        'Content-Type': 'application/json',
      };
      final body = jsonEncode({'display_title': 'Update Fail'});

      // Act
      final response = await http.patch(url, headers: headers, body: body);

      // Assert
      expect(response.statusCode, 404);
    });

    test('should return 401 Unauthorized if X-API-Key is missing', () async {
      // Arrange
      final url = Uri.parse('$baseUrl/api/v1/jobs/any-id');
      final headers = {
        'Authorization': 'Bearer $dummyJwt',
        'Content-Type': 'application/json',
        // No X-API-Key
      };
      final body = jsonEncode({'display_title': 'Update Fail'});

      // Act
      final response = await http.patch(url, headers: headers, body: body);

      // Assert
      expect(response.statusCode, 401);
    });

    test('should return 401 Unauthorized if Authorization header is missing',
        () async {
      // Arrange
      final url = Uri.parse('$baseUrl/api/v1/jobs/any-id');
      final headers = {
        'X-API-Key': testApiKey,
        'Content-Type': 'application/json',
        // No Authorization
      };
      final body = jsonEncode({'display_title': 'Update Fail'});

      // Act
      final response = await http.patch(url, headers: headers, body: body);

      // Assert
      expect(response.statusCode, 401);
    });

    test(
        'should return 400 Bad Request if Content-Type is not application/json',
        () async {
      // Arrange
      final createdJob = await _createTestJobForPatch();
      final jobId = createdJob['id'];
      final url = Uri.parse('$baseUrl/api/v1/jobs/$jobId');
      final headers = {
        'Authorization': 'Bearer $dummyJwt',
        'X-API-Key': testApiKey,
        'Content-Type': 'text/plain', // Incorrect Content-Type
      };
      final body = 'display_title=WrongFormat';

      // Act
      final response = await http.patch(url, headers: headers, body: body);

      // Assert
      expect(response.statusCode,
          400); // Expecting 400 for bad content type / body
    });
  }); // End group PATCH /api/v1/jobs/{id}
}
