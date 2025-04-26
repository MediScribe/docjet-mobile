import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:docjet_mobile/core/auth/auth_credentials_provider.dart';
import 'package:docjet_mobile/core/config/api_config.dart';
import 'package:docjet_mobile/core/user/infrastructure/dtos/user_profile_dto.dart';
import 'package:docjet_mobile/core/user/infrastructure/user_api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockDio extends Mock implements Dio {}

class MockAuthCredentialsProvider extends Mock
    implements AuthCredentialsProvider {}

class MockResponse extends Mock implements Response {}

void main() {
  late UserApiClient userApiClient;
  late MockDio authenticatedDio;
  late MockAuthCredentialsProvider credentialsProvider;

  setUp(() {
    authenticatedDio = MockDio();
    credentialsProvider = MockAuthCredentialsProvider();

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
      when(() => mockResponse.statusCode).thenReturn(200);
      when(() => mockResponse.data).thenReturn(mockProfileResponse);

      when(
        () => authenticatedDio.get(any()),
      ).thenAnswer((_) async => mockResponse);
      when(
        () => credentialsProvider.getAccessToken(),
      ).thenAnswer((_) async => 'mock-jwt-token');

      // Act
      final result = await userApiClient.getUserProfile();

      // Assert
      verify(
        () => authenticatedDio.get(ApiConfig.userProfileEndpoint),
      ).called(1);
      expect(result, isA<UserProfileDto>());
      expect(result.id, equals('user-123'));
      expect(result.email, equals('test@example.com'));
    });

    test('getUserProfile should throw exception on error', () async {
      // Arrange
      when(() => authenticatedDio.get(any())).thenThrow(
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
      when(() => mockResponse.statusCode).thenReturn(401);

      when(
        () => authenticatedDio.get(any()),
      ).thenAnswer((_) async => mockResponse);

      // Act & Assert
      expect(
        () => userApiClient.getUserProfile(),
        throwsA(isA<DioException>()),
      );
    });
  });
}
