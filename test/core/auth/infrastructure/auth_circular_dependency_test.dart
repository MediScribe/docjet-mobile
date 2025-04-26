import 'package:flutter_test/flutter_test.dart';
import 'package:docjet_mobile/core/auth/auth_credentials_provider.dart';
import 'package:docjet_mobile/core/auth/events/auth_event_bus.dart';
import 'package:docjet_mobile/core/auth/infrastructure/auth_api_client.dart';
import 'package:docjet_mobile/core/auth/infrastructure/auth_interceptor.dart';
import 'package:docjet_mobile/core/auth/infrastructure/dtos/auth_response_dto.dart';
import 'package:dio/dio.dart';

void main() {
  group('Auth Circular Dependency Test', () {
    late Dio basicDio;
    late AuthCredentialsProvider credentialsProvider;
    late AuthEventBus eventBus;
    late AuthApiClient authApiClient;

    setUp(() {
      basicDio = Dio();
      credentialsProvider = _FakeCredentialsProvider();
      eventBus = _FakeEventBus();
      authApiClient = _FakeAuthApiClient(basicDio, credentialsProvider);
    });

    test('Function-based DI breaks circular dependency', () {
      // 1. Create an AuthInterceptor using function-based DI
      final interceptor = AuthInterceptor(
        refreshTokenFunction: (token) => authApiClient.refreshToken(token),
        credentialsProvider: credentialsProvider,
        dio: basicDio,
        authEventBus: eventBus,
      );

      expect(
        interceptor,
        isNotNull,
        reason: 'Should be able to create interceptor',
      );

      // 2. The key test - we can now create a new AuthApiClient that depends on a Dio
      // with the interceptor, and the circular dependency is broken
      final authenticatedDio = Dio()..interceptors.add(interceptor);

      final newApiClient = AuthApiClient(
        httpClient: authenticatedDio,
        credentialsProvider: credentialsProvider,
      );

      expect(
        newApiClient,
        isNotNull,
        reason: 'Should be able to create AuthApiClient with authenticatedDio',
      );

      // 3. Verify the circular references were successfully established
      expect(
        identical(newApiClient.httpClient, authenticatedDio),
        isTrue,
        reason: 'ApiClient should reference authenticatedDio',
      );

      expect(
        authenticatedDio.interceptors.contains(interceptor),
        isTrue,
        reason: 'Dio should have the interceptor',
      );
    });
  });
}

// Simple test fakes to avoid complex mock setup
class _FakeCredentialsProvider implements AuthCredentialsProvider {
  @override
  Future<String?> getAccessToken() async => 'fake-access-token';

  @override
  Future<String?> getRefreshToken() async => 'fake-refresh-token';

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeEventBus implements AuthEventBus {
  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAuthApiClient extends AuthApiClient {
  _FakeAuthApiClient(Dio httpClient, AuthCredentialsProvider provider)
    : super(httpClient: httpClient, credentialsProvider: provider);

  @override
  Future<AuthResponseDto> refreshToken(String refreshToken) async {
    return AuthResponseDto(
      accessToken: 'new-access-token',
      refreshToken: 'new-refresh-token',
      userId: 'user-123',
    );
  }
}
