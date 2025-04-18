import 'dart:typed_data'; // For Uint8List

import 'package:dio/dio.dart';
import 'package:docjet_mobile/core/auth/auth_credentials_provider.dart'; // Import provider
import 'package:docjet_mobile/core/error/exceptions.dart';
import 'package:docjet_mobile/features/jobs/data/datasources/api_job_remote_data_source_impl.dart'; // Will not exist yet
import 'package:docjet_mobile/features/jobs/domain/entities/job.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job_status.dart'; // Import the enum
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart'; // Import mockito annotations
import 'package:mockito/mockito.dart';

// Import the generated mocks file (will be created by build_runner)
import 'api_job_remote_data_source_impl_test.mocks.dart';

// Helper function to load fixtures (sample JSON files)
String fixture(String name) =>
    'test/fixtures/$name'; // Assuming fixtures are in test/fixtures/

// --- REMOVED: Unused Helper Function --- //

// Annotation to generate mocks for Dio and the new provider
// Use GenerateNiceMocks as recommended by the documentation
@GenerateNiceMocks([MockSpec<Dio>(), MockSpec<AuthCredentialsProvider>()])
void main() {
  late MockDio mockDio; // Use MockDio instead of Dio
  late MockAuthCredentialsProvider
  mockAuthCredentialsProvider; // Mock for the provider
  late ApiJobRemoteDataSourceImpl dataSource; // The class under test

  // --- Test Setup --- //
  setUp(() {
    mockDio = MockDio();
    mockAuthCredentialsProvider =
        MockAuthCredentialsProvider(); // Instantiate mock provider

    // Create a dummy MultipartFile instance for tests
    final dummyMultipartFile = MultipartFile.fromBytes(
      Uint8List(0), // Empty bytes
      filename: 'test_audio.mp3',
    );

    // Mock creator function that returns the dummy file instantly
    Future<MultipartFile> mockCreator(String path) async {
      // We can add checks here later if needed (e.g., verify path format)
      // For now, just return the dummy file regardless of path.
      return dummyMultipartFile;
    }

    // Instantiate the data source, injecting the mock Dio, mock provider, and mock creator
    dataSource = ApiJobRemoteDataSourceImpl(
      dio: mockDio,
      authCredentialsProvider: mockAuthCredentialsProvider, // Provide the mock
      multipartFileCreator: mockCreator,
    );
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
    localId: tJobId,
    userId: tUserId,
    status: JobStatus.completed, // Assert Enum
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
    when(mockDio.get(path, options: anyNamed('options'))).thenAnswer(
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
        const testApiKey = 'test-api-key';
        const testToken = 'test-jwt-token';

        // Stub the provider methods
        when(
          mockAuthCredentialsProvider.getApiKey(),
        ).thenAnswer((_) async => testApiKey);
        when(
          mockAuthCredentialsProvider.getAccessToken(),
        ).thenAnswer((_) async => testToken);

        setUpMockGetSuccess('/jobs/$tJobId', tJobJson);

        // Act
        final result = await dataSource.fetchJobById(tJobId);

        // Assert
        expect(result, equals(tJobEntity));

        // Verify dio.get was called and capture the options
        final capturedOptions =
            verify(
                  mockDio.get(
                    '/jobs/$tJobId',
                    options: captureAnyNamed('options'),
                  ),
                ).captured.single
                as Options;

        // Verify the headers in the captured options
        expect(capturedOptions.headers, containsPair('X-API-Key', testApiKey));
        expect(
          capturedOptions.headers,
          containsPair('Authorization', 'Bearer $testToken'),
        );
        expect(
          capturedOptions.headers,
          containsPair('Content-Type', 'application/json'),
        );
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
        // We still expect the credential provider to be called even if the API call fails later
        verify(mockAuthCredentialsProvider.getApiKey()).called(1);
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
        // Verify credential provider was called
        verify(mockAuthCredentialsProvider.getApiKey()).called(1);
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
  });

  group('fetchJobs', () {
    test(
      'should perform GET request on /jobs and return List<Job> on 200 success',
      () async {
        // Arrange
        const testApiKey = 'test-api-key';
        const testToken = 'test-jwt-token';
        when(
          mockAuthCredentialsProvider.getApiKey(),
        ).thenAnswer((_) async => testApiKey);
        when(
          mockAuthCredentialsProvider.getAccessToken(),
        ).thenAnswer((_) async => testToken);

        // Use the tJobListJson which contains a list under the "data" key
        setUpMockGetSuccess('/jobs', tJobListJson);
        // Act
        final result = await dataSource.fetchJobs();
        // Assert
        expect(
          result,
          equals(tJobList),
        ); // tJobList uses tJobEntity, which now has Enum
        // Verify options were captured and headers are correct
        final capturedOptions =
            verify(
                  mockDio.get('/jobs', options: captureAnyNamed('options')),
                ).captured.single
                as Options;
        expect(capturedOptions.headers, containsPair('X-API-Key', testApiKey));
        expect(
          capturedOptions.headers,
          containsPair('Authorization', 'Bearer $testToken'),
        );
      },
    );

    test(
      'should return empty list when response is 200 but data list is empty',
      () async {
        // Arrange
        const testApiKey = 'test-api-key';
        const testToken = 'test-jwt-token';
        when(
          mockAuthCredentialsProvider.getApiKey(),
        ).thenAnswer((_) async => testApiKey);
        when(
          mockAuthCredentialsProvider.getAccessToken(),
        ).thenAnswer((_) async => testToken);

        final emptyListJson = {"data": [], "pagination": {}}; // Empty data list
        setUpMockGetSuccess('/jobs', emptyListJson);
        // Act
        final result = await dataSource.fetchJobs();
        // Assert
        expect(result, equals(<Job>[])); // Expect an empty list of Jobs
        // Verify options/headers even for empty list success
        final capturedOptions =
            verify(
                  mockDio.get('/jobs', options: captureAnyNamed('options')),
                ).captured.single
                as Options;
        expect(capturedOptions.headers, containsPair('X-API-Key', testApiKey));
      },
    );

    test(
      'should throw ApiException when the response code is 500 (Server Error)',
      () async {
        // Arrange
        const testApiKey = 'test-api-key';
        const testToken = 'test-jwt-token';
        when(
          mockAuthCredentialsProvider.getApiKey(),
        ).thenAnswer((_) async => testApiKey);
        when(
          mockAuthCredentialsProvider.getAccessToken(),
        ).thenAnswer((_) async => testToken);

        setUpMockGetFailure('/jobs', 500, {'error': 'Server went boom'});
        // Act
        final call = dataSource.fetchJobs;
        // Assert
        await expectLater(() => call(), throwsA(isA<ApiException>()));
        // Verify credential provider was called
        verify(mockAuthCredentialsProvider.getApiKey()).called(1);
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
    // Test data for createJob response
    final tCreateJobResponseJson = {
      "data": {
        "id": "new-job-uuid-789",
        "user_id": tUserId,
        "job_status": "submitted", // API returns string
        "created_at": "2024-01-16T12:00:00.000Z",
        "updated_at": "2024-01-16T12:00:00.000Z",
        "text": "Uploaded text",
        "additional_text": null,
        // Spec says display_title and display_text are null in create response
        "display_title": null,
        "display_text": null,
      },
    };

    // Expected Job entity corresponding to tCreateJobResponseJson
    // Updated to match the actual implementation logic:
    // - Uses status from response (mapped to enum)
    // - Uses timestamps from response
    // - Uses text/additionalText from response
    // - Uses displayTitle/displayText from response (which are null)
    // - Uses audioFilePath passed into the createJob call
    // - Error fields are null
    final tCreatedJobEntity = Job(
      localId: "new-job-uuid-789",
      userId: tUserId,
      status: JobStatus.submitted, // Expect Enum based on "submitted"
      createdAt: DateTime.parse("2024-01-16T12:00:00.000Z"),
      updatedAt: DateTime.parse("2024-01-16T12:00:00.000Z"),
      text: "Uploaded text", // From response
      additionalText: null, // From response
      displayTitle: null, // From response
      displayText: null, // From response
      errorCode: null, // Not in response
      errorMessage: null, // Not in response
      audioFilePath: tAudioPath, // From input parameter to createJob
    );

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
        const testApiKey = 'test-api-key';
        const testToken = 'test-jwt-token';
        when(
          mockAuthCredentialsProvider.getApiKey(),
        ).thenAnswer((_) async => testApiKey);
        when(
          mockAuthCredentialsProvider.getAccessToken(),
        ).thenAnswer((_) async => testToken);

        setUpMockPostSuccess(
          tCreateJobResponseJson,
        ); // Use tCreateJobResponseJson as the success response body

        // Act
        final result = await dataSource.createJob(
          userId: tUserId,
          audioFilePath:
              tAudioPath, // Path is needed, but file access is not directly tested
          text: 'Test text',
          additionalText: 'Test additional text',
          // No testAudioFile parameter anymore
        );

        // Assert
        expect(
          result,
          equals(tCreatedJobEntity),
        ); // Expect the parsed Job entity

        // --- Verify the call to dio.post --- //
        final captured =
            verify(
              mockDio.post(
                '/jobs',
                // Capture the data argument
                data: captureAnyNamed('data'),
                options: captureAnyNamed('options'),
              ),
            ).captured;
        // Assert that the captured data is indeed FormData
        expect(captured[0], isA<FormData>());
        // Assert headers in captured options (index 1)
        final capturedOptions = captured[1] as Options;
        expect(capturedOptions.headers, containsPair('X-API-Key', testApiKey));
        expect(
          capturedOptions.headers,
          containsPair('Authorization', 'Bearer $testToken'),
        );
        // Content-Type is handled by Dio for FormData, so don't check it strictly here
      },
    );

    test('should throw ApiException on 400 Bad Request', () async {
      // Arrange
      const testApiKey = 'test-api-key';
      const testToken = 'test-jwt-token';
      when(
        mockAuthCredentialsProvider.getApiKey(),
      ).thenAnswer((_) async => testApiKey);
      when(
        mockAuthCredentialsProvider.getAccessToken(),
      ).thenAnswer((_) async => testToken);

      final responseBody = {'error': 'Missing required field: user_id'};
      setUpMockPostFailure(400, responseBody); // Mock a 400 response

      // Act
      final call = dataSource.createJob;

      // Assert
      await expectLater(
        () => call(
          userId: tUserId, // Provide necessary args
          audioFilePath: tAudioPath,
          // No testAudioFile
        ),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', 400),
        ),
      );

      // Verify dio.post was still called and capture data
      final captured =
          verify(
            mockDio.post(
              '/jobs',
              data: captureAnyNamed('data'),
              options: anyNamed('options'),
            ),
          ).captured;
      expect(
        captured[0],
        isA<FormData>(),
      ); // Check captured data type (index 0)
      // Verify credential provider was called
      verify(mockAuthCredentialsProvider.getApiKey()).called(1);
    });

    test('should throw ApiException on 500 Server Error', () async {
      // Arrange
      const testApiKey = 'test-api-key';
      const testToken = 'test-jwt-token';
      when(
        mockAuthCredentialsProvider.getApiKey(),
      ).thenAnswer((_) async => testApiKey);
      when(
        mockAuthCredentialsProvider.getAccessToken(),
      ).thenAnswer((_) async => testToken);

      final responseBody = {'error': 'Internal Server Error'};
      setUpMockPostFailure(500, responseBody); // Mock a 500 response

      // Act
      final call = dataSource.createJob;

      // Assert
      await expectLater(
        () => call(
          userId: tUserId,
          audioFilePath: tAudioPath,
          // No testAudioFile
        ),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', 500),
        ),
      );

      // Verify dio.post was still called and capture data
      final captured =
          verify(
            mockDio.post(
              '/jobs',
              data: captureAnyNamed('data'),
              options: anyNamed('options'),
            ),
          ).captured;
      expect(
        captured[0],
        isA<FormData>(),
      ); // Check captured data type (index 0)
      // Verify credential provider was called
      verify(mockAuthCredentialsProvider.getApiKey()).called(1);
    });

    test('should throw ApiException on network/connection error', () async {
      // Arrange
      // Stub credentials even when Dio throws
      const testApiKey = 'test-api-key';
      const testToken = 'test-jwt-token';
      when(
        mockAuthCredentialsProvider.getApiKey(),
      ).thenAnswer((_) async => testApiKey);
      when(
        mockAuthCredentialsProvider.getAccessToken(),
      ).thenAnswer((_) async => testToken);

      final exception = DioException(
        requestOptions: RequestOptions(path: '/jobs'),
        error: 'Connection refused',
        type: DioExceptionType.connectionError,
      );
      when(
        mockDio.post(
          '/jobs',
          // Use anyNamed here since we aren't capturing/verifying the data in this case
          data: anyNamed('data'),
          options: anyNamed('options'),
        ),
      ).thenThrow(exception);

      // Act
      final call = dataSource.createJob;

      // Assert
      await expectLater(
        () => call(userId: tUserId, audioFilePath: tAudioPath),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', isNull),
        ),
      );

      // Verify dio.post was still called, but don't need to capture data
      verify(
        mockDio.post(
          '/jobs',
          data: anyNamed('data'),
          options: anyNamed('options'),
        ),
      );
      // No need to check captured data here as the focus is the thrown exception.
    });
  });

  // --- Tests for updateJob --- //
  group('updateJob', () {
    final tUpdatePayload = {
      'text': 'Updated transcript text',
      'display_title': 'Updated Title',
    };

    // Test data for updateJob response (assuming API returns the updated job)
    final tUpdateJobResponseJson = {
      "data": {
        "id": tJobId,
        "user_id": tUserId,
        "job_status": "transcribed", // API returns string
        "error_code": null,
        "error_message": null,
        "created_at":
            "2024-01-15T10:00:00.000Z", // Assume timestamps might update
        "updated_at": "2024-01-16T13:00:00.000Z",
        "text": "Updated transcript text",
        "additional_text": "More info", // Assume unchanged
        "display_title": "Updated Title",
        "display_text":
            "Patient presented with symptoms...", // Assume unchanged
      },
    };

    // Expected Job entity corresponding to tUpdateJobResponseJson
    final tUpdatedJobEntity = Job(
      localId: tJobId,
      userId: tUserId,
      status: JobStatus.transcribed, // Expect Enum
      errorCode: null,
      errorMessage: null,
      createdAt: DateTime.parse("2024-01-15T10:00:00.000Z"),
      updatedAt: DateTime.parse("2024-01-16T13:00:00.000Z"),
      text: "Updated transcript text",
      additionalText: "More info",
      displayTitle: "Updated Title",
      displayText: "Patient presented with symptoms...",
      audioFilePath: null, // Not relevant for update response
    );

    // Helper to setup successful PATCH mock
    void setUpMockPatchSuccess(
      String path,
      dynamic requestBody,
      dynamic responseBody,
    ) {
      when(
        mockDio.patch(
          path,
          // Use anyNamed for data and options in the stub
          data: anyNamed('data'),
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
          // Use anyNamed for data and options in the stub
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
      'should perform PATCH request on /jobs/{id} with JSON data and return Job on 200 success',
      () async {
        // Arrange
        const testApiKey = 'test-api-key';
        const testToken = 'test-jwt-token';
        when(
          mockAuthCredentialsProvider.getApiKey(),
        ).thenAnswer((_) async => testApiKey);
        when(
          mockAuthCredentialsProvider.getAccessToken(),
        ).thenAnswer((_) async => testToken);

        final path = '/jobs/$tJobId';
        setUpMockPatchSuccess(path, tUpdatePayload, tUpdateJobResponseJson);

        // Act
        final result = await dataSource.updateJob(
          jobId: tJobId,
          updates: tUpdatePayload,
        );

        // Assert
        expect(
          result,
          equals(tUpdatedJobEntity),
        ); // Compare with the expected Enum entity

        // Verify the call was made once with the right parameters
        // Use specific payload for data, and anyNamed for options
        final verification = verify(
          mockDio.patch(
            path,
            data: captureAnyNamed('data'),
            options: captureAnyNamed('options'),
          ),
        );
        verification.called(1);

        // Verify the captured data and options
        expect(verification.captured[0], equals(tUpdatePayload));
        final capturedOptions = verification.captured[1] as Options;

        // Verify headers in the captured options
        expect(capturedOptions.headers, containsPair('X-API-Key', testApiKey));
        expect(
          capturedOptions.headers,
          containsPair('Authorization', 'Bearer $testToken'),
        );
        expect(
          capturedOptions.headers,
          containsPair('Content-Type', 'application/json'),
        );
      },
    );

    test(
      'should throw ApiException when the response code is 404 (Not Found)',
      () async {
        // Arrange
        const testApiKey = 'test-api-key';
        const testToken = 'test-jwt-token';
        when(
          mockAuthCredentialsProvider.getApiKey(),
        ).thenAnswer((_) async => testApiKey);
        when(
          mockAuthCredentialsProvider.getAccessToken(),
        ).thenAnswer((_) async => testToken);

        final path = '/jobs/$tJobId';
        final responseBody = {'error': 'Job not found'};
        // Use the corrected failure helper
        setUpMockPatchFailure(path, 404, responseBody);

        // Act
        final call = dataSource.updateJob;

        // Assert
        // Use expectLater with the correct matcher
        await expectLater(
          () => call(jobId: tJobId, updates: tUpdatePayload),
          throwsA(
            isA<ApiException>().having((e) => e.statusCode, 'statusCode', 404),
          ),
        );
        // Verify credential provider was called
        verify(mockAuthCredentialsProvider.getApiKey()).called(1);
        // Verify patch was called (optional, but good practice)
        verify(
          mockDio.patch(
            path,
            data: anyNamed('data'),
            options: anyNamed('options'),
          ),
        ).called(1);
      },
    );

    test(
      'should throw ApiException when the response code is 400 (Bad Request)',
      () async {
        // Arrange
        const testApiKey = 'test-api-key';
        const testToken = 'test-jwt-token';
        when(
          mockAuthCredentialsProvider.getApiKey(),
        ).thenAnswer((_) async => testApiKey);
        when(
          mockAuthCredentialsProvider.getAccessToken(),
        ).thenAnswer((_) async => testToken);

        final path = '/jobs/$tJobId';
        final responseBody = {'error': 'Invalid field in update'};
        // Use the corrected failure helper
        setUpMockPatchFailure(path, 400, responseBody);

        // Act
        final call = dataSource.updateJob;

        // Assert
        // Use expectLater with the correct matcher
        await expectLater(
          () => call(jobId: tJobId, updates: tUpdatePayload),
          throwsA(
            isA<ApiException>().having((e) => e.statusCode, 'statusCode', 400),
          ),
        );
        // Verify credential provider was called
        verify(mockAuthCredentialsProvider.getApiKey()).called(1);
        // Verify patch was called
        verify(
          mockDio.patch(
            path,
            data: anyNamed('data'),
            options: anyNamed('options'),
          ),
        ).called(1);
      },
    );

    test(
      'should throw ApiException when the response code is 500 (Server Error)',
      () async {
        // Arrange
        const testApiKey = 'test-api-key';
        const testToken = 'test-jwt-token';
        when(
          mockAuthCredentialsProvider.getApiKey(),
        ).thenAnswer((_) async => testApiKey);
        when(
          mockAuthCredentialsProvider.getAccessToken(),
        ).thenAnswer((_) async => testToken);

        final path = '/jobs/$tJobId';
        final responseBody = {'error': 'Internal Server Error'};
        // Use the corrected failure helper
        setUpMockPatchFailure(path, 500, responseBody);

        // Act
        final call = dataSource.updateJob;

        // Assert
        // Use expectLater with the correct matcher
        await expectLater(
          () => call(jobId: tJobId, updates: tUpdatePayload),
          throwsA(
            isA<ApiException>().having((e) => e.statusCode, 'statusCode', 500),
          ),
        );
        // Verify credential provider was called
        verify(mockAuthCredentialsProvider.getApiKey()).called(1);
        // Verify patch was called
        verify(
          mockDio.patch(
            path,
            data: anyNamed('data'),
            options: anyNamed('options'),
          ),
        ).called(1);
      },
    );

    test('should throw ApiException on network/connection error', () async {
      // Arrange
      // Stub credentials even when Dio throws
      const testApiKey = 'test-api-key';
      const testToken = 'test-jwt-token';
      when(
        mockAuthCredentialsProvider.getApiKey(),
      ).thenAnswer((_) async => testApiKey);
      when(
        mockAuthCredentialsProvider.getAccessToken(),
      ).thenAnswer((_) async => testToken);

      final path = '/jobs/$tJobId';
      final exception = DioException(
        requestOptions: RequestOptions(path: path),
        error: 'Connection timed out',
        type: DioExceptionType.connectionTimeout,
      );
      // Configure mockDio.patch to throw the exception
      // Use anyNamed matchers for the stub when throwing
      when(
        mockDio.patch(
          path,
          data: anyNamed('data'),
          options: anyNamed('options'),
        ),
      ).thenThrow(exception);

      // Act
      final call = dataSource.updateJob;

      // Assert
      await expectLater(
        () => call(jobId: tJobId, updates: tUpdatePayload),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', isNull),
        ),
      );
      // Verify credential provider was still called before Dio threw
      verify(mockAuthCredentialsProvider.getApiKey()).called(1);
      // Verify patch was called
      verify(
        mockDio.patch(
          path,
          data: anyNamed('data'),
          options: anyNamed('options'),
        ),
      ).called(1);
    });
  });
}
