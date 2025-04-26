import 'package:dio/dio.dart';
import 'package:docjet_mobile/core/auth/auth_credentials_provider.dart';
import 'package:docjet_mobile/core/auth/infrastructure/auth_api_client.dart';
import 'package:docjet_mobile/core/auth/infrastructure/auth_service_impl.dart';
import 'package:docjet_mobile/core/auth/events/auth_event_bus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/src/mock.dart';

@GenerateMocks([AuthCredentialsProvider, Dio, AuthEventBus])
import 'auth_flow_test.mocks.dart';

void main() {
  late MockDio mockBasicDio;
  late MockDio mockAuthenticatedDio;
  late MockAuthCredentialsProvider mockCredentialsProvider;
  late MockAuthEventBus mockEventBus;
  late AuthApiClient authApiClient;
  late AuthServiceImpl authService;

  setUp(() {
    mockBasicDio = MockDio();
    mockAuthenticatedDio = MockDio();
    mockCredentialsProvider = MockAuthCredentialsProvider();
    mockEventBus = MockAuthEventBus();

    // Setup auth client with mockBasicDio
    authApiClient = AuthApiClient(
      httpClient: mockBasicDio,
      credentialsProvider: mockCredentialsProvider,
    );

    // Setup auth service with the auth client
    authService = AuthServiceImpl(
      apiClient: authApiClient,
      credentialsProvider: mockCredentialsProvider,
      eventBus: mockEventBus,
    );

    // Default setup for credential provider
    when(
      mockCredentialsProvider.getApiKey(),
    ).thenAnswer((_) async => 'test-api-key');
    when(
      mockCredentialsProvider.setAccessToken(any),
    ).thenAnswer((_) async => {});
    when(
      mockCredentialsProvider.setRefreshToken(any),
    ).thenAnswer((_) async => {});
    when(mockCredentialsProvider.setUserId(any)).thenAnswer((_) async => {});
    when(
      mockCredentialsProvider.getUserId(),
    ).thenAnswer((_) async => 'test-user-id');
  });

  group('Authentication Flow', () {
    test(
      'Login flow should succeed but getUserProfile should fail with 401',
      () async {
        // Arrange - Setup mock login response
        final loginResponse = {
          'access_token': 'test-access-token',
          'refresh_token': 'test-refresh-token',
          'user_id': 'test-user-id',
        };

        // Setup mockBasicDio to return successful login response
        when(mockBasicDio.post(any, data: anyNamed('data'))).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(path: '/api/v1/auth/login'),
            data: loginResponse,
            statusCode: 200,
          ),
        );

        // Setup mockBasicDio to fail on getUserProfile with 401
        when(mockBasicDio.get(any)).thenThrow(
          DioException(
            requestOptions: RequestOptions(path: '/api/v1/users/profile'),
            response: Response(
              requestOptions: RequestOptions(path: '/api/v1/users/profile'),
              statusCode: 401,
              data: {'error': 'Missing or invalid Authorization header'},
            ),
            type: DioExceptionType.badResponse,
          ),
        );

        // Act & Assert - Login should succeed
        final user = await authService.login('test@example.com', 'password');
        expect(user.id, equals('test-user-id'));

        // Verify tokens were stored
        verify(
          mockCredentialsProvider.setAccessToken('test-access-token'),
        ).called(1);
        verify(
          mockCredentialsProvider.setRefreshToken('test-refresh-token'),
        ).called(1);
        verify(mockCredentialsProvider.setUserId('test-user-id')).called(1);

        // Verify login event was fired
        verify(mockEventBus.add(any)).called(1);

        // Act & Assert - getUserProfile should fail with 401
        expectLater(
          () => authService.getUserProfile(),
          throwsA(anything), // Will throw some auth exception
        );
      },
    );

    test('getUserProfile needs JWT token in Authorization header', () async {
      // This test demonstrates how to fix the issue

      // 1. First create the API client with authenticatedDio
      final fixedApiClient = AuthApiClient(
        httpClient: mockAuthenticatedDio,
        credentialsProvider: mockCredentialsProvider,
      );

      // 2. Create auth service with the API client using authenticatedDio
      final fixedAuthService = AuthServiceImpl(
        apiClient: fixedApiClient,
        credentialsProvider: mockCredentialsProvider,
        eventBus: mockEventBus,
      );

      // Setup credential provider to return a token
      when(
        mockCredentialsProvider.getAccessToken(),
      ).thenAnswer((_) async => 'test-access-token');

      // Setup mockAuthenticatedDio to verify Authorization header
      when(mockAuthenticatedDio.get(any)).thenAnswer((invocation) async {
        // Return success only if the request has the Authorization header
        final RequestOptions options = invocation.positionalArguments[0];

        // Check if the Authorization header is present and contains the token
        if (options.headers.containsKey('Authorization') &&
            options.headers['Authorization'] == 'Bearer test-access-token') {
          return Response(
            requestOptions: options,
            data: {'id': 'test-user-id', 'name': 'Test User'},
            statusCode: 200,
          );
        } else {
          throw DioException(
            requestOptions: options,
            response: Response(
              requestOptions: options,
              statusCode: 401,
              data: {'error': 'Missing or invalid Authorization header'},
            ),
            type: DioExceptionType.badResponse,
          );
        }
      });

      // Act & Assert - getUserProfile should succeed with authenticated Dio
      await fixedAuthService.getUserProfile();

      // Verify the header was checked
      verify(mockCredentialsProvider.getAccessToken()).called(1);
    });
  });
}
