import 'package:dio/dio.dart';
import 'package:docjet_mobile/core/auth/auth_credentials_provider.dart';
import 'package:docjet_mobile/core/auth/auth_session_provider.dart';
import 'package:docjet_mobile/core/error/exceptions.dart';
import 'package:docjet_mobile/core/platform/file_system.dart';
import 'package:docjet_mobile/features/jobs/data/datasources/api_job_remote_data_source_impl.dart';
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
  });
}
