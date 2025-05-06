import 'package:dio/dio.dart';
import 'package:docjet_mobile/core/config/api_config.dart';
import 'package:docjet_mobile/core/user/infrastructure/dtos/user_profile_dto.dart';
import 'package:docjet_mobile/core/user/infrastructure/user_api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'user_api_client_test.mocks.dart';

@GenerateMocks([Dio, Response])
void main() {
  late UserApiClient userApiClient;
  late MockDio authenticatedDio;
  final mockUserId = 'user-123'; // Test user ID

  setUp(() {
    authenticatedDio = MockDio();

    userApiClient = UserApiClient(authenticatedHttpClient: authenticatedDio);
  });

  group('UserApiClient', () {
    final mockProfileResponse = {
      'id': 'user-123',
      'email': 'test@example.com',
      'name': 'Test User Name',
      'settings': {'theme': 'dark', 'language': 'en'},
    };

    test('getUserProfile should use authenticatedDio', () async {
      // Arrange
      final mockResponse = MockResponse();
      when(mockResponse.statusCode).thenReturn(200);
      when(mockResponse.data).thenReturn(mockProfileResponse);

      final expectedEndpoint =
          ApiConfig.userProfileEndpoint; // This is now 'users/me'

      // Mock the UNTRANSFORMED endpoint from ApiConfig
      when(
        authenticatedDio.get(expectedEndpoint),
      ).thenAnswer((_) async => mockResponse);

      // Act
      final result = await userApiClient.getUserProfile();

      // Assert - Verify the UNTRANSFORMED endpoint was expected
      verify(authenticatedDio.get(expectedEndpoint)).called(1);
      expect(result, isA<UserProfileDto>());
      expect(
        result.id,
        equals(mockUserId),
      ); // This comes from mockProfileResponse, not path
      expect(result.email, equals('test@example.com'));
      expect(result.name, equals('Test User Name'));
      expect(result.settings, equals({'theme': 'dark', 'language': 'en'}));
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

    test(
      'getUserProfile should throw DioException with correct status on 404 not found',
      () async {
        // Arrange
        final mockResponse = MockResponse();
        when(mockResponse.statusCode).thenReturn(404);
        // Ensure data is null or a valid type if Dio expects it for error responses
        when(mockResponse.data).thenReturn(null);

        final requestOptions = RequestOptions(
          path: ApiConfig.userProfileEndpoint,
        );
        when(mockResponse.requestOptions).thenReturn(requestOptions);

        when(
          authenticatedDio.get(ApiConfig.userProfileEndpoint),
        ).thenAnswer((_) async => mockResponse);

        // Act & Assert
        try {
          await userApiClient.getUserProfile();
          fail('Should have thrown DioException');
        } on DioException catch (e) {
          expect(e.response?.statusCode, equals(404));
          expect(e.type, equals(DioExceptionType.badResponse));
          expect(e.requestOptions.path, ApiConfig.userProfileEndpoint);
        } catch (e) {
          fail('Threw unexpected exception type: ${e.runtimeType}');
        }
      },
    );
  });
}
