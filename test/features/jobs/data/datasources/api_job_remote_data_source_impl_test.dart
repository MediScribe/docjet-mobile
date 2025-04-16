import 'dart:convert'; // For jsonDecode
import 'dart:typed_data'; // For Uint8List

import 'package:dio/dio.dart';
import 'package:docjet_mobile/core/error/exceptions.dart';
import 'package:docjet_mobile/features/jobs/data/datasources/api_job_remote_data_source_impl.dart'; // Will not exist yet
import 'package:docjet_mobile/features/jobs/domain/entities/job.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart'; // Import mockito annotations
import 'package:mockito/mockito.dart'; // Import mockito

// Import the generated mocks file (will be created by build_runner)
import 'api_job_remote_data_source_impl_test.mocks.dart';

// Helper function to load fixtures (sample JSON files)
String fixture(String name) =>
    'test/fixtures/$name'; // Assuming fixtures are in test/fixtures/

// --- Helper Function for FormData Verification --- //
void _verifyCreateJobFormData({
  required List<dynamic> capturedData,
  required String expectedUserId,
  required String expectedText,
  required String expectedAdditionalText,
  required String expectedFilename,
}) {
  // Ensure exactly one call was captured and it's FormData
  expect(capturedData.length, 1, reason: 'Should capture exactly one call');
  expect(
    capturedData.single,
    isA<FormData>(),
    reason: 'Captured data should be FormData',
  );

  // Cast to FormData for easier field/file access
  final formData = capturedData.single as FormData;

  // Check required fields
  expect(
    formData.fields.any((f) => f.key == 'user_id' && f.value == expectedUserId),
    isTrue,
    reason: 'FormData should contain user_id field with correct value',
  );

  // Check optional fields that were provided
  expect(
    formData.fields.any((f) => f.key == 'text' && f.value == expectedText),
    isTrue,
    reason: 'FormData should contain text field with correct value',
  );
  expect(
    formData.fields.any(
      (f) => f.key == 'additional_text' && f.value == expectedAdditionalText,
    ),
    isTrue,
    reason: 'FormData should contain additional_text field with correct value',
  );

  // Check the file part
  expect(
    formData.files.any(
      (f) => f.key == 'audio_file' && f.value.filename == expectedFilename,
    ),
    isTrue,
    reason: 'FormData should contain audio_file with correct filename',
  );
}

// Annotation to generate mocks for Dio
@GenerateMocks([Dio])
void main() {
  late MockDio mockDio; // Use MockDio instead of Dio
  late ApiJobRemoteDataSourceImpl dataSource; // The class under test

  setUp(() {
    // Create the mock Dio instance
    mockDio = MockDio();
    // Instantiate the data source implementation WITH THE MOCK
    dataSource = ApiJobRemoteDataSourceImpl(dio: mockDio);
  });

  // --- Test data setup ---
  final tJobId = 'job-uuid-123';
  final tUserId = 'user-uuid-456';
  final tAudioPath = '/path/to/audio.mp3';

  // Sample JSON response for GET /jobs/{id}
  final tJobJson = {
    "data": {
      "id": tJobId,
      "user_id": tUserId,
      "job_status":
          "completed", // Note: spec uses job_status, Job entity uses status
      "error_code": null,
      "error_message": null,
      "created_at": "2024-01-15T10:00:00.000Z",
      "updated_at": "2024-01-15T11:30:00.000Z",
      "text": "Initial notes",
      "additional_text": "More info",
      "display_title": "Consultation Jan 15",
      "display_text": "Patient presented with symptoms...",
    },
  };

  // Expected Job entity corresponding to tJobJson
  final tJobEntity = Job(
    id: tJobId,
    userId: tUserId,
    status: "completed", // Mapping from job_status
    errorCode: null,
    errorMessage: null,
    createdAt: DateTime.parse("2024-01-15T10:00:00.000Z"),
    updatedAt: DateTime.parse("2024-01-15T11:30:00.000Z"),
    text: "Initial notes",
    additionalText: "More info",
    displayTitle: "Consultation Jan 15",
    displayText: "Patient presented with symptoms...",
    audioFilePath: null, // Not present in API response for GET
  );

  // Sample JSON response for GET /jobs
  final tJobListJson = {
    "data": [tJobJson["data"]], // Reuse the single job data for simplicity
    "pagination": {"limit": 20, "offset": 0, "total": 1},
  };

  final tJobList = [tJobEntity]; // Expected list of Job entities

  // Helper function to setup successful GET request mock
  void setUpMockGetSuccess(String path, dynamic responseBody) {
    // Use Mockito to stub the dio.get method
    when(
      // Match the specific path
      mockDio.get(path, options: anyNamed('options')),
    ).thenAnswer(
      (_) async => Response(
        requestOptions: RequestOptions(path: path),
        data: responseBody,
        statusCode: 200,
      ),
    );
  }

  // Helper function to setup failed GET request mock
  void setUpMockGetFailure(String path, int statusCode, dynamic responseBody) {
    when(mockDio.get(path, options: anyNamed('options'))).thenAnswer(
      (_) async => Response(
        requestOptions: RequestOptions(path: path),
        data: responseBody,
        statusCode: statusCode,
      ),
    );
  }

  // --- Tests will go here ---

  group('fetchJobById', () {
    // First test case (RED)
    test(
      'should perform GET request on /jobs/{id} and return Job on 200 success',
      () async {
        // Arrange
        setUpMockGetSuccess('/jobs/$tJobId', tJobJson);
        // Act
        final result = await dataSource.fetchJobById(tJobId);
        // Assert
        expect(result, equals(tJobEntity));
        // We don't verify dio calls directly, the adapter handles interception.
        // Verification focuses on the *outcome* (correct Job entity returned).
      },
    );

    test(
      'should throw ApiException when the response code is 404 (Not Found)',
      () async {
        // Arrange
        setUpMockGetFailure('/jobs/$tJobId', 404, {'error': 'Not Found'});
        // Act
        final call = dataSource.fetchJobById;
        // Assert
        await expectLater(() => call(tJobId), throwsA(isA<ApiException>()));
        // Optional: Check specific properties of the exception if needed
        // await expectLater(() => call(tJobId), throwsA(predicate((e) => e is ApiException && e.statusCode == 404)));
      },
    );

    test(
      'should throw ApiException when the response code is 500 (Server Error)',
      () async {
        // Arrange
        setUpMockGetFailure('/jobs/$tJobId', 500, {
          'error': 'Internal Server Error',
        });
        // Act
        final call = dataSource.fetchJobById;
        // Assert
        await expectLater(() => call(tJobId), throwsA(isA<ApiException>()));
        // Optional: Check specific properties
        // await expectLater(() => call(tJobId), throwsA(predicate((e) => e is ApiException && e.statusCode == 500)));
      },
    );

    test('should throw ApiException on network/connection error', () async {
      // Arrange
      final exception = DioException(
        requestOptions: RequestOptions(path: '/jobs/$tJobId'),
        error: 'Connection failed', // Example error
        type: DioExceptionType.connectionTimeout, // Example type
      );
      // Stub dio.get to throw the exception
      when(mockDio.get(any, options: anyNamed('options'))).thenThrow(exception);

      // Act
      final call = dataSource.fetchJobById;
      // Assert
      await expectLater(() => call(tJobId), throwsA(isA<ApiException>()));
    });

    // TODO: Add test for network/connection errors (adapter might throw DioException)
  });

  group('fetchJobs', () {
    test(
      'should perform GET request on /jobs and return List<Job> on 200 success',
      () async {
        // Arrange
        // Use the tJobListJson which contains a list under the "data" key
        setUpMockGetSuccess('/jobs', tJobListJson);
        // Act
        final result = await dataSource.fetchJobs();
        // Assert
        expect(result, equals(tJobList));
      },
    );

    test(
      'should return empty list when response is 200 but data list is empty',
      () async {
        // Arrange
        final emptyListJson = {"data": [], "pagination": {}}; // Empty data list
        setUpMockGetSuccess('/jobs', emptyListJson);
        // Act
        final result = await dataSource.fetchJobs();
        // Assert
        expect(result, equals(<Job>[])); // Expect an empty list of Jobs
      },
    );

    test(
      'should throw ApiException when the response code is 500 (Server Error)',
      () async {
        // Arrange
        setUpMockGetFailure('/jobs', 500, {'error': 'Server went boom'});
        // Act
        final call = dataSource.fetchJobs;
        // Assert
        await expectLater(() => call(), throwsA(isA<ApiException>()));
      },
    );

    test('should throw ApiException on network/connection error', () async {
      // Arrange
      final exception = DioException(
        requestOptions: RequestOptions(path: '/jobs'),
        error: 'Connection refused',
        type: DioExceptionType.connectionError,
      );
      // Stub dio.get to throw the exception for the /jobs path
      when(
        mockDio.get('/jobs', options: anyNamed('options')),
      ).thenThrow(exception);

      // Act
      final call = dataSource.fetchJobs;
      // Assert
      await expectLater(() => call(), throwsA(isA<ApiException>()));
    });

    // TODO: Add test for network/connection errors
  });

  group('createJob', () {
    // --- Testing Note --- //
    // Initial attempts to test this method used `http_mock_adapter`.
    // However, mocking multipart/form-data requests with `http_mock_adapter`
    // proved problematic due to Dio automatically generating dynamic
    // `Content-Type` (with boundary) and `Content-Length` headers for FormData.
    // The mock adapter struggled to match these dynamic requests reliably,
    // leading to `Could not find mocked route` errors even when matching only
    // the path and method.
    //
    // The solution is to mock the `Dio` client directly using `mockito`.
    // This approach bypasses the complexities of HTTP-level matching for FormData
    // and allows us to directly verify that `createJob` calls `dio.post`
    // with the expected path (`/jobs`) and handles the mocked success/error
    // responses or exceptions correctly. This keeps the unit test focused on
    // the logic within `ApiJobRemoteDataSourceImpl` itself.
    // -------------------- //

    // Helper to setup successful POST mock
    void setUpMockPostSuccess(dynamic responseBody) {
      // Use Mockito to stub the dio.post method
      when(
        // Match the path, any data, and any options
        mockDio.post(
          '/jobs',
          data: anyNamed('data'),
          options: anyNamed('options'),
        ),
      ).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/jobs'),
          data: responseBody,
          statusCode: 201,
        ),
      );
    }

    // Helper to setup failed POST mock
    void setUpMockPostFailure(int statusCode, dynamic responseBody) {
      when(
        mockDio.post(
          '/jobs',
          data: anyNamed('data'),
          options: anyNamed('options'),
        ),
      ).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/jobs'),
          data: responseBody,
          statusCode: statusCode,
        ),
      );
    }

    test(
      'should perform POST request with FormData and return Job on 201 success',
      () async {
        // Arrange
        setUpMockPostSuccess(
          tJobJson,
        ); // Use tJobJson as the success response body

        // Create a dummy MultipartFile for testing
        final testAudioBytes = Uint8List.fromList(
          utf8.encode('test audio content'),
        );
        final testAudioFile = MultipartFile.fromBytes(
          testAudioBytes,
          filename: 'test_audio.mp3',
        );

        // Act
        final result = await dataSource.createJob(
          userId: tUserId,
          audioFilePath:
              tAudioPath, // This path won't be accessed due to the testAudioFile
          text: 'Test text',
          additionalText: 'Test additional text',
          testAudioFile:
              testAudioFile, // Pass the test file to avoid actual file operations
        );

        // Assert
        expect(result, equals(tJobEntity)); // Expect the parsed Job entity

        // --- Verify the call to dio.post and capture the FormData --- //
        final captured =
            verify(
              mockDio.post(
                '/jobs',
                // Capture the data argument
                data: captureAnyNamed('data'),
                // Ensure options were passed (any options)
                options: anyNamed('options'),
              ),
            ).captured;

        // --- Call the helper function to verify FormData --- //
        _verifyCreateJobFormData(
          capturedData: captured,
          expectedUserId: tUserId,
          expectedText: 'Test text',
          expectedAdditionalText: 'Test additional text',
          expectedFilename: 'test_audio.mp3',
        );
      },
    );

    test('should throw ApiException on 400 Bad Request', () async {
      // Arrange
      final responseBody = {'error': 'Missing required field: user_id'};
      setUpMockPostFailure(400, responseBody); // Mock a 400 response

      // Create dummy file data (needed to call the method, content irrelevant for this test)
      final testAudioFile = MultipartFile.fromBytes([], filename: 'dummy.mp3');

      // Act
      final call = dataSource.createJob;

      // Assert
      // Expect an ApiException to be thrown when createJob is called
      await expectLater(
        () => call(
          userId: tUserId, // Provide necessary args
          audioFilePath: tAudioPath,
          testAudioFile: testAudioFile,
          // Other optional args can be omitted or provided as needed
        ),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', 400),
        ),
      ); // Verify it's an ApiException with statusCode 400
    });

    test('should throw ApiException on 500 Server Error', () async {
      // Arrange
      final responseBody = {'error': 'Internal Server Error'};
      setUpMockPostFailure(500, responseBody); // Mock a 500 response

      // Create dummy file data
      final testAudioFile = MultipartFile.fromBytes([], filename: 'dummy.mp3');

      // Act
      final call = dataSource.createJob;

      // Assert
      await expectLater(
        () => call(
          userId: tUserId,
          audioFilePath: tAudioPath,
          testAudioFile: testAudioFile,
        ),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', 500),
        ),
      ); // Verify it's an ApiException with statusCode 500
    });

    test('should throw ApiException on network/connection error', () async {
      // Arrange
      final exception = DioException(
        requestOptions: RequestOptions(path: '/jobs'),
        error: 'Connection refused', // Example network error
        type: DioExceptionType.connectionError,
      );
      // Configure mockDio.post to throw the exception
      when(
        mockDio.post(
          '/jobs',
          data: anyNamed('data'),
          options: anyNamed('options'),
        ),
      ).thenThrow(exception); // Throw DioException on post

      // Create dummy file data
      final testAudioFile = MultipartFile.fromBytes([], filename: 'dummy.mp3');

      // Act
      final call = dataSource.createJob;

      // Assert
      // Expect an ApiException because the DioException should be caught and wrapped
      await expectLater(
        () => call(
          userId: tUserId,
          audioFilePath: tAudioPath,
          testAudioFile: testAudioFile,
        ),
        throwsA(
          isA<ApiException>().having(
            // Network errors typically don't have a status code from the response
            (e) => e.statusCode,
            'statusCode',
            isNull,
          ),
        ),
      );
    });

    // TODO: Consider verifying the FormData structure more specifically if needed
  });

  // --- Tests for updateJob --- //
  group('updateJob', () {
    final tUpdatePayload = {
      'text': 'Updated notes',
      'display_title': 'Updated Title',
      'display_text': 'Updated snippet...',
    };

    // Define an expected Job entity after the update
    // Assume the API returns the full, updated job object
    final tUpdatedJobEntity = Job(
      id: tJobId, // Same job ID
      userId: tUserId, // Same user ID
      status: "transcribed", // Example status after update
      errorCode: null,
      errorMessage: null,
      createdAt: DateTime.parse(
        "2024-01-15T10:00:00.000Z",
      ), // Original creation time
      updatedAt: DateTime.parse("2024-01-15T12:00:00.000Z"), // New updated time
      text: tUpdatePayload['text'] as String,
      additionalText: "More info", // Assuming this wasn't updated
      displayTitle: tUpdatePayload['display_title'] as String,
      displayText: tUpdatePayload['display_text'] as String,
      audioFilePath: null,
    );

    // Corresponding JSON response for the updated job
    final tUpdatedJobJson = {
      "data": {
        "id": tUpdatedJobEntity.id,
        "user_id": tUpdatedJobEntity.userId,
        "job_status": tUpdatedJobEntity.status,
        "error_code": tUpdatedJobEntity.errorCode,
        "error_message": tUpdatedJobEntity.errorMessage,
        "created_at": tUpdatedJobEntity.createdAt.toIso8601String(),
        "updated_at": tUpdatedJobEntity.updatedAt.toIso8601String(),
        "text": tUpdatedJobEntity.text,
        "additional_text": tUpdatedJobEntity.additionalText,
        "display_title": tUpdatedJobEntity.displayTitle,
        "display_text": tUpdatedJobEntity.displayText,
      },
    };

    // Helper to setup successful PATCH mock
    void setUpMockPatchSuccess(
      String path,
      dynamic requestBody,
      dynamic responseBody,
    ) {
      when(
        mockDio.patch(
          path,
          data: requestBody, // Match the specific request body
          options: anyNamed('options'),
        ),
      ).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: path),
          data: responseBody,
          statusCode: 200,
        ),
      );
    }

    // Helper function to setup failed PATCH request mock
    void setUpMockPatchFailure(
      String path,
      int statusCode,
      dynamic responseBody,
    ) {
      when(
        mockDio.patch(
          path,
          // Use anyNamed('data') for the named argument, even in failure mocks
          data: anyNamed('data'),
          options: anyNamed('options'),
        ),
      ).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: path),
          data: responseBody,
          statusCode: statusCode,
        ),
      );
    }

    test(
      'should perform PATCH request with data and return updated Job on 200 success',
      () async {
        // Arrange
        final path = '/jobs/$tJobId';
        setUpMockPatchSuccess(path, tUpdatePayload, tUpdatedJobJson);

        // Act
        final result = await dataSource.updateJob(
          jobId: tJobId,
          updates: tUpdatePayload,
        );

        // Assert
        expect(result, equals(tUpdatedJobEntity));
        verify(
          mockDio.patch(
            path,
            data: tUpdatePayload, // Verify the exact payload was sent
            options: anyNamed('options'),
          ),
        ).called(1);
      },
    );

    test(
      'should throw ApiException when the response code is 404 (Not Found)',
      () async {
        // Arrange
        final path = '/jobs/$tJobId';
        final responseBody = {'error': 'Job not found'};
        // Call the simplified helper
        setUpMockPatchFailure(path, 404, responseBody);

        // Act
        final call = dataSource.updateJob;

        // Assert
        await expectLater(
          () => call(jobId: tJobId, updates: tUpdatePayload),
          throwsA(
            isA<ApiException>().having((e) => e.statusCode, 'statusCode', 404),
          ),
        );
      },
    );

    test(
      'should throw ApiException when the response code is 400 (Bad Request)',
      () async {
        // Arrange
        final path = '/jobs/$tJobId';
        final responseBody = {'error': 'Invalid field in update'};
        setUpMockPatchFailure(path, 400, responseBody); // Mock 400

        // Act
        final call = dataSource.updateJob;

        // Assert
        await expectLater(
          () =>
              call(jobId: tJobId, updates: tUpdatePayload), // Send some payload
          throwsA(
            isA<ApiException>().having((e) => e.statusCode, 'statusCode', 400),
          ),
        );
      },
    );

    test(
      'should throw ApiException when the response code is 500 (Server Error)',
      () async {
        // Arrange
        final path = '/jobs/$tJobId';
        final responseBody = {'error': 'Internal Server Error'};
        setUpMockPatchFailure(path, 500, responseBody); // Mock 500

        // Act
        final call = dataSource.updateJob;

        // Assert
        await expectLater(
          () => call(jobId: tJobId, updates: tUpdatePayload),
          throwsA(
            isA<ApiException>().having((e) => e.statusCode, 'statusCode', 500),
          ),
        );
      },
    );

    test('should throw ApiException on network/connection error', () async {
      // Arrange
      final path = '/jobs/$tJobId';
      final exception = DioException(
        requestOptions: RequestOptions(path: path),
        error: 'Connection timed out',
        type: DioExceptionType.connectionTimeout,
      );
      // Configure mockDio.patch to throw the exception
      when(
        mockDio.patch(
          path,
          data: anyNamed('data'), // Matcher for named arg
          options: anyNamed('options'),
        ),
      ).thenThrow(exception);

      // Act
      final call = dataSource.updateJob;

      // Assert
      await expectLater(
        () => call(jobId: tJobId, updates: tUpdatePayload),
        throwsA(
          isA<ApiException>().having(
            // Should be caught and wrapped, statusCode is usually null for DioException
            (e) => e.statusCode,
            'statusCode',
            isNull,
          ),
        ),
      );
    });
  });
}
