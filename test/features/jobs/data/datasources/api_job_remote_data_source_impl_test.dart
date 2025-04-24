import 'package:dio/dio.dart';
import 'package:docjet_mobile/core/auth/auth_credentials_provider.dart';
import 'package:docjet_mobile/core/auth/auth_session_provider.dart';
import 'package:docjet_mobile/core/error/exceptions.dart';
import 'package:docjet_mobile/features/jobs/data/datasources/api_job_remote_data_source_impl.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job_status.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/sync_status.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

// Generate mocks for the dependencies
@GenerateMocks([Dio, AuthCredentialsProvider, AuthSessionProvider])
// Import the generated mocks
import 'api_job_remote_data_source_impl_test.mocks.dart';

void main() {
  late ApiJobRemoteDataSourceImpl remoteDataSource;
  late MockDio mockDio;
  late MockAuthCredentialsProvider mockAuthCredentialsProvider;
  late MockAuthSessionProvider mockAuthSessionProvider;

  // Test data
  final tApiKey = 'test-api-key';
  final tAccessToken = 'test-access-token';
  final tUserId = 'test-user-id';
  final tAudioFilePath = '/path/to/audio.mp3';
  final tText = 'Test job text';

  // Custom function to create mock MultipartFile without requiring file system
  Future<MultipartFile> mockMultipartFileCreator(String path) async {
    return MultipartFile.fromString('test-content', filename: 'test-audio.mp3');
  }

  setUp(() {
    mockDio = MockDio();
    mockAuthCredentialsProvider = MockAuthCredentialsProvider();
    mockAuthSessionProvider = MockAuthSessionProvider();

    remoteDataSource = ApiJobRemoteDataSourceImpl(
      dio: mockDio,
      authCredentialsProvider: mockAuthCredentialsProvider,
      authSessionProvider: mockAuthSessionProvider,
      multipartFileCreator: mockMultipartFileCreator,
    );

    // Default stubs for auth providers
    when(
      mockAuthCredentialsProvider.getApiKey(),
    ).thenAnswer((_) async => tApiKey);
    when(
      mockAuthCredentialsProvider.getAccessToken(),
    ).thenAnswer((_) async => tAccessToken);
    when(mockAuthSessionProvider.getCurrentUserId()).thenReturn(tUserId);
    when(mockAuthSessionProvider.isAuthenticated()).thenReturn(true);
  });

  group('createJob', () {
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
      when(mockAuthSessionProvider.isAuthenticated()).thenReturn(false);

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
