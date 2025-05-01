import 'package:dio/dio.dart';
import 'package:docjet_mobile/core/auth/auth_credentials_provider.dart';
import 'package:docjet_mobile/core/config/api_config.dart';
import 'package:docjet_mobile/core/user/infrastructure/dtos/user_profile_dto.dart';
import 'package:docjet_mobile/core/user/infrastructure/user_api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'user_api_client_test.mocks.dart';

@GenerateMocks([Dio, AuthCredentialsProvider, Response])
void main() {
  late UserApiClient userApiClient;
  late MockDio authenticatedDio;
  late MockAuthCredentialsProvider credentialsProvider;
  final mockUserId = 'user-123'; // Test user ID

  setUp(() {
    authenticatedDio = MockDio();
    credentialsProvider = MockAuthCredentialsProvider();

    // Mock getUserId to return a consistent ID for tests
    when(credentialsProvider.getUserId()).thenAnswer((_) async => mockUserId);

    userApiClient = UserApiClient(
      authenticatedHttpClient: authenticatedDio,
      credentialsProvider: credentialsProvider,
    );
  });

  group('UserApiClient', () {
    final mockProfileResponse = {
      'id': 'user-123',
      'email': 'test@example.com',
      'name': 'Test User',
      'settings': {'theme': 'dark'},
    };

    test('getUserProfile should use authenticatedDio', () async {
      // Arrange
      final mockResponse = MockResponse();
      when(mockResponse.statusCode).thenReturn(200);
      when(mockResponse.data).thenReturn(mockProfileResponse);

      // TODO: Remove this workaround test logic when HACK_profile_endpoint_workaround is removed.
      // Calculate the expected endpoint after the hack transformation
      final expectedEndpoint = 'users/$mockUserId';

      // Mock the specific transformed endpoint
      when(
        authenticatedDio.get(expectedEndpoint),
      ).thenAnswer((_) async => mockResponse);
      // We still need the getAccessToken mock for the JWT decoding part of the hack
      when(
        credentialsProvider.getAccessToken(),
      ).thenAnswer((_) async => 'mock-jwt-token-with-sub-$mockUserId');

      // Act
      final result = await userApiClient.getUserProfile();

      // Assert - Verify the EXACT transformed endpoint was called
      // TODO: Change verification back to ApiConfig.userProfileEndpoint when hack is removed.
      verify(authenticatedDio.get(expectedEndpoint)).called(1);
      expect(result, isA<UserProfileDto>());
      expect(result.id, equals(mockUserId));
      expect(result.email, equals('test@example.com'));
    });

    test('getUserProfile should throw exception on error', () async {
      // Arrange
      when(authenticatedDio.get(any)).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: ApiConfig.userProfileEndpoint),
          error: 'Error getting user profile',
          type: DioExceptionType.unknown,
        ),
      );

      // Act & Assert
      expect(
        () => userApiClient.getUserProfile(),
        throwsA(isA<DioException>()),
      );
    });

    test('getUserProfile should throw exception on 401 unauthorized', () async {
      // Arrange
      final mockResponse = MockResponse();
      when(mockResponse.statusCode).thenReturn(401);

      when(authenticatedDio.get(any)).thenAnswer((_) async => mockResponse);

      // Act & Assert
      expect(
        () => userApiClient.getUserProfile(),
        throwsA(isA<DioException>()),
      );
    });
  });
}
