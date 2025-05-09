import 'package:dio/dio.dart';
import 'package:docjet_mobile/core/auth/auth_credentials_provider.dart';
import 'package:docjet_mobile/core/auth/auth_session_provider.dart';
import 'package:docjet_mobile/core/error/exceptions.dart';
import 'package:docjet_mobile/core/platform/file_system.dart';
import 'package:docjet_mobile/features/jobs/data/datasources/api_job_remote_data_source_impl.dart';
import 'package:docjet_mobile/features/jobs/data/models/job_api_dto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

// Generate mocks for the dependencies
@GenerateMocks([Dio, AuthCredentialsProvider, AuthSessionProvider, FileSystem])
// Import the generated mocks
import 'api_job_remote_data_source_impl_test.mocks.dart';

void main() {
  late ApiJobRemoteDataSourceImpl remoteDataSource;
  late MockDio mockDio;
  late MockAuthCredentialsProvider mockAuthCredentialsProvider;
  late MockAuthSessionProvider mockAuthSessionProvider;
  late MockFileSystem mockFileSystem;

  // Test data
  const tApiKey = 'test-api-key';
  const tAccessToken = 'test-access-token';
  const tUserId = 'test-user-id';
  const tAudioFilePath = '/path/to/audio.mp3';
  const tResolvedAudioPath = '/resolved/path/to/audio.mp3';
  const tText = 'Test job text';

  // Track calls to multipartFileCreator to verify the path passed
  String? capturedMultipartPath;

  // Custom function to create mock MultipartFile without requiring file system
  Future<MultipartFile> mockMultipartFileCreator(String path) async {
    capturedMultipartPath = path;
    return MultipartFile.fromString('test-content', filename: 'test-audio.mp3');
  }

  setUp(() {
    mockDio = MockDio();
    mockAuthCredentialsProvider = MockAuthCredentialsProvider();
    mockAuthSessionProvider = MockAuthSessionProvider();
    mockFileSystem = MockFileSystem();
    capturedMultipartPath = null;

    remoteDataSource = ApiJobRemoteDataSourceImpl(
      dio: mockDio,
      authCredentialsProvider: mockAuthCredentialsProvider,
      authSessionProvider: mockAuthSessionProvider,
      fileSystem: mockFileSystem,
      multipartFileCreator: mockMultipartFileCreator,
    );

    // Default stubs for auth providers
    when(
      mockAuthCredentialsProvider.getApiKey(),
    ).thenAnswer((_) async => tApiKey);
    when(
      mockAuthCredentialsProvider.getAccessToken(),
    ).thenAnswer((_) async => tAccessToken);
    when(
      mockAuthSessionProvider.getCurrentUserId(),
    ).thenAnswer((_) async => tUserId);
    when(
      mockAuthSessionProvider.isAuthenticated(),
    ).thenAnswer((_) async => true);

    // Default stub for FileSystem
    when(mockFileSystem.resolvePath(any)).thenReturn(tResolvedAudioPath);

    // Provide default BaseOptions so that accessing dio.options works in tests
    when(
      mockDio.options,
    ).thenReturn(BaseOptions(baseUrl: 'https://staging.docjet.ai/api/v1/'));
  });

  group('createJob', () {
    test(
      'should resolve the audio file path using FileSystem when creating a job',
      () async {
        // Arrange
        final responseData = {
          'data': {
            'id': 'server-123',
            'user_id': tUserId,
            'job_status': 'submitted',
            'created_at': '2023-01-01T00:00:00.000Z',
            'updated_at': '2023-01-01T00:00:00.000Z',
            'text': tText,
          },
        };

        when(
          mockDio.post(
            argThat(anything),
            data: anyNamed('data'),
            options: anyNamed('options'),
          ),
        ).thenAnswer(
          (_) async => Response(
            data: responseData,
            statusCode: 201,
            requestOptions: RequestOptions(path: '/jobs'),
          ),
        );

        // Act
        await remoteDataSource.createJob(
          audioFilePath: tAudioFilePath,
          text: tText,
        );

        // Assert
        // Verify that FileSystem.resolvePath was called with the original path
        verify(mockFileSystem.resolvePath(tAudioFilePath)).called(1);

        // Verify that multipartFileCreator was called with the resolved path
        expect(capturedMultipartPath, equals(tResolvedAudioPath));
      },
    );

    test(
      'should get userId from AuthSessionProvider when creating a job',
      () async {
        // Arrange
        // Mock successful response
        final responseData = {
          'data': {
            'id': 'server-123',
            'user_id': tUserId,
            'job_status': 'submitted',
            'created_at': '2023-01-01T00:00:00.000Z',
            'updated_at': '2023-01-01T00:00:00.000Z',
            'text': tText,
          },
        };

        when(
          mockDio.post(
            argThat(anything),
            data: anyNamed('data'),
            options: anyNamed('options'),
          ),
        ).thenAnswer(
          (_) async => Response(
            data: responseData,
            statusCode: 201,
            requestOptions: RequestOptions(path: '/jobs'),
          ),
        );

        // Act
        await remoteDataSource.createJob(
          audioFilePath: tAudioFilePath,
          text: tText,
        );

        // Assert
        // Verify that getCurrentUserId was called on the auth session provider
        verify(mockAuthSessionProvider.getCurrentUserId()).called(1);
        verify(mockAuthSessionProvider.isAuthenticated()).called(1);
      },
    );

    test('should throw ApiException when user is not authenticated', () async {
      // Arrange
      when(
        mockAuthSessionProvider.isAuthenticated(),
      ).thenAnswer((_) async => false);

      // Act & Assert
      expect(
        () => remoteDataSource.createJob(audioFilePath: tAudioFilePath),
        throwsA(isA<ApiException>()),
      );

      // No API call should be made
      verifyNever(
        mockDio.post(
          argThat(anything),
          data: anyNamed('data'),
          options: anyNamed('options'),
        ),
      );
    });

    test(
      'should throw ApiException when getCurrentUserId throws an exception',
      () async {
        // Arrange
        when(
          mockAuthSessionProvider.isAuthenticated(),
        ).thenAnswer((_) async => true);
        when(
          mockAuthSessionProvider.getCurrentUserId(),
        ).thenThrow(Exception('Auth error'));

        // Act & Assert
        expect(
          () => remoteDataSource.createJob(audioFilePath: tAudioFilePath),
          throwsA(
            isA<ApiException>().having(
              (e) => e.message,
              'message',
              contains('Authentication failed'),
            ),
          ),
        );

        // No API call should be made
        verifyNever(
          mockDio.post(
            argThat(anything),
            data: anyNamed('data'),
            options: anyNamed('options'),
          ),
        );
      },
    );

    test(
      'should include user ID from auth session provider in form data',
      () async {
        // Arrange
        final responseData = {
          'data': {
            'id': 'server-123',
            'user_id': tUserId,
            'job_status': 'submitted',
            'created_at': '2023-01-01T00:00:00.000Z',
            'updated_at': '2023-01-01T00:00:00.000Z',
            'text': tText,
          },
        };

        // Set up the mock response first
        when(
          mockDio.post(
            argThat(anything),
            data: anyNamed('data'),
            options: anyNamed('options'),
          ),
        ).thenAnswer(
          (_) async => Response(
            data: responseData,
            statusCode: 201,
            requestOptions: RequestOptions(path: '/jobs'),
          ),
        );

        // Act
        await remoteDataSource.createJob(
          audioFilePath: tAudioFilePath,
          text: tText,
        );

        // Assert
        // Capture the FormData that was passed to post
        final captured =
            verify(
              mockDio.post(
                any,
                data: captureAnyNamed('data'),
                options: anyNamed('options'),
              ),
            ).captured;

        // The captured data should be a FormData object
        expect(captured.first, isA<FormData>());
        final formData = captured.first as FormData;

        // Verify formData.fields contains an entry with key 'user_id' and value from the auth provider
        expect(
          formData.fields,
          contains(
            predicate<MapEntry<String, String>>(
              (entry) => entry.key == 'user_id' && entry.value == tUserId,
            ),
          ),
        );
      },
    );

    test(
      'should include an Origin header derived from baseUrl for multipart requests',
      () async {
        // Arrange
        final responseData = {
          'data': {
            'id': 'server-123',
            'user_id': tUserId,
            'job_status': 'submitted',
            'created_at': '2023-01-01T00:00:00.000Z',
            'updated_at': '2023-01-01T00:00:00.000Z',
            'text': tText,
          },
        };

        when(
          mockDio.post(
            argThat(anything),
            data: anyNamed('data'),
            options: anyNamed('options'),
          ),
        ).thenAnswer(
          (_) async => Response(
            data: responseData,
            statusCode: 201,
            requestOptions: RequestOptions(path: '/jobs'),
          ),
        );

        // Act
        await remoteDataSource.createJob(
          audioFilePath: tAudioFilePath,
          text: tText,
        );

        // Assert
        final capturedOptions =
            verify(
                  mockDio.post(
                    any,
                    data: anyNamed('data'),
                    options: captureAnyNamed('options'),
                  ),
                ).captured.first
                as Options;

        expect(capturedOptions.headers?['Origin'], 'https://staging.docjet.ai');
      },
    );
  });

  group('fetchJobs', () {
    test(
      'should return a List<JobApiDTO> with all fields correctly parsed when fetchJobs is called',
      () async {
        // Arrange
        // Setup mock response with multiple jobs
        final jobsListJson = {
          'data': [
            {
              'id': 'server-id-1',
              'user_id': tUserId,
              'job_status': 'submitted',
              'created_at': '2023-01-01T00:00:00.000Z',
              'updated_at': '2023-01-01T00:00:00.000Z',
              'display_title': 'Job 1 Title',
              'display_text': 'Job 1 Text',
              'text': 'Transcription 1',
              'additional_text': 'Additional 1',
            },
            {
              'id': 'server-id-2',
              'user_id': tUserId,
              'job_status': 'completed',
              'created_at': '2023-01-02T00:00:00.000Z',
              'updated_at': '2023-01-02T00:00:00.000Z',
              'display_title': 'Job 2 Title',
              'display_text': 'Job 2 Text',
              'text': 'Transcription 2',
              'error_code': 0,
              'error_message': null,
            },
            {
              'id': 'server-id-3',
              'user_id': tUserId,
              'job_status': 'error',
              'created_at': '2023-01-03T00:00:00.000Z',
              'updated_at': '2023-01-03T00:00:00.000Z',
              'display_title': null,
              'display_text': null,
              'text': null,
              'error_code': 500,
              'error_message': 'Processing failed',
            },
          ],
        };

        // Setup the dio mock with the correct matcher
        when(
          mockDio.get(argThat(equals('/jobs')), options: anyNamed('options')),
        ).thenAnswer(
          (_) async => Response(
            data: jobsListJson,
            statusCode: 200,
            requestOptions: RequestOptions(path: '/jobs'),
          ),
        );

        // Act
        final result = await remoteDataSource.fetchJobs();

        // Assert
        // 1. Verify the result type
        expect(result, isA<List<JobApiDTO>>());
        expect(result.length, 3);

        // 2. Verify the first DTO has correct values
        expect(result[0].id, 'server-id-1');
        expect(result[0].userId, tUserId);
        expect(result[0].jobStatus, 'submitted');
        expect(result[0].createdAt, DateTime.parse('2023-01-01T00:00:00.000Z'));
        expect(result[0].updatedAt, DateTime.parse('2023-01-01T00:00:00.000Z'));
        expect(result[0].displayTitle, 'Job 1 Title');
        expect(result[0].displayText, 'Job 1 Text');
        expect(result[0].text, 'Transcription 1');
        expect(result[0].additionalText, 'Additional 1');

        // 3. Verify the second DTO has correct values
        expect(result[1].id, 'server-id-2');
        expect(result[1].jobStatus, 'completed');
        expect(result[1].errorCode, 0);
        expect(result[1].errorMessage, null);

        // 4. Verify the third DTO has correct values (with error fields)
        expect(result[2].id, 'server-id-3');
        expect(result[2].jobStatus, 'error');
        expect(result[2].displayTitle, null);
        expect(result[2].text, null);
        expect(result[2].errorCode, 500);
        expect(result[2].errorMessage, 'Processing failed');
      },
    );

    test(
      'should throw ApiException when the API returns a non-200 status code',
      () async {
        // Arrange
        when(
          mockDio.get(argThat(equals('/jobs')), options: anyNamed('options')),
        ).thenAnswer(
          (_) async => Response(
            data: {'error': 'Server error'},
            statusCode: 500,
            requestOptions: RequestOptions(path: '/jobs'),
          ),
        );

        // Act & Assert
        expect(
          () => remoteDataSource.fetchJobs(),
          throwsA(isA<ApiException>()),
        );
      },
    );

    test('should throw ApiException when Dio throws a DioException', () async {
      // Arrange
      when(
        mockDio.get(argThat(equals('/jobs')), options: anyNamed('options')),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/jobs'),
          message: 'Network error',
        ),
      );

      // Act & Assert
      expect(() => remoteDataSource.fetchJobs(), throwsA(isA<ApiException>()));
    });

    test('should throw ApiException when user is not authenticated', () async {
      // Arrange
      when(
        mockAuthSessionProvider.isAuthenticated(),
      ).thenAnswer((_) async => false);

      // Act & Assert
      expect(() => remoteDataSource.fetchJobs(), throwsA(isA<ApiException>()));
    });
  });
}
