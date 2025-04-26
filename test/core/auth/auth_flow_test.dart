import 'package:dio/dio.dart';
import 'package:docjet_mobile/core/auth/auth_credentials_provider.dart';
import 'package:docjet_mobile/core/auth/infrastructure/auth_service_impl.dart';
import 'package:docjet_mobile/core/auth/events/auth_event_bus.dart';
import 'package:docjet_mobile/core/auth/infrastructure/authentication_api_client.dart';
import 'package:docjet_mobile/core/user/infrastructure/user_api_client.dart';
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
  late AuthenticationApiClient authenticationApiClient;
  late UserApiClient userApiClient;
  late AuthServiceImpl authService;

  setUp(() {
    mockBasicDio = MockDio();
    mockAuthenticatedDio = MockDio();
    mockCredentialsProvider = MockAuthCredentialsProvider();
    mockEventBus = MockAuthEventBus();

    // Setup auth client with mockBasicDio
    authenticationApiClient = AuthenticationApiClient(
      basicHttpClient: mockBasicDio,
      credentialsProvider: mockCredentialsProvider,
    );

    // Setup user client with mockAuthenticatedDio
    userApiClient = UserApiClient(
      authenticatedHttpClient:
          mockBasicDio, // Using mockBasicDio to demonstrate the issue
      credentialsProvider: mockCredentialsProvider,
    );

    // Setup auth service with both clients
    authService = AuthServiceImpl(
      authenticationApiClient: authenticationApiClient,
      userApiClient: userApiClient,
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
      // This test demonstrates the Split Client architecture
      // It verifies that getUserProfile uses authenticatedDio (via UserApiClient)

      // 1. First create the API clients properly
      final fixedAuthenticationApiClient = AuthenticationApiClient(
        basicHttpClient: mockBasicDio,
        credentialsProvider: mockCredentialsProvider,
      );

      final fixedUserApiClient = UserApiClient(
        authenticatedHttpClient: mockAuthenticatedDio,
        credentialsProvider: mockCredentialsProvider,
      );

      // 2. Create auth service with both API clients
      final fixedAuthService = AuthServiceImpl(
        authenticationApiClient: fixedAuthenticationApiClient,
        userApiClient: fixedUserApiClient,
        credentialsProvider: mockCredentialsProvider,
        eventBus: mockEventBus,
      );

      // Setup credential provider to return a token and user ID
      when(
        mockCredentialsProvider.getUserId(),
      ).thenAnswer((_) async => 'test-user-id');
      when(
        mockCredentialsProvider.getAccessToken(),
      ).thenAnswer((_) async => 'test-access-token');

      // Setup mockAuthenticatedDio with any response
      when(mockAuthenticatedDio.get(any)).thenAnswer((_) async {
        return Response(
          requestOptions: RequestOptions(path: '/api/v1/users/profile'),
          data: {'id': 'test-user-id', 'email': 'test@example.com'},
          statusCode: 200,
        );
      });

      // Make basicDio throw if it's used for profile (which would be wrong)
      when(
        mockBasicDio.get(any),
      ).thenThrow(Exception('BasicDio should not be used for profile'));

      // Try to get profile
      try {
        await fixedAuthService.getUserProfile();
      } catch (_) {
        // Ignore any errors, the important part is which client was used
      }

      // The critical verification: authenticatedDio was used, not basicDio
      verify(mockAuthenticatedDio.get(any)).called(1);
      verifyNever(mockBasicDio.get(any));
    });

    test('API calls should use the appropriate clients', () async {
      // Create auth service with mock clients
      final mockAuthenticationApiClient = AuthenticationApiClient(
        basicHttpClient: mockBasicDio,
        credentialsProvider: mockCredentialsProvider,
      );

      final mockUserApiClient = UserApiClient(
        authenticatedHttpClient: mockAuthenticatedDio,
        credentialsProvider: mockCredentialsProvider,
      );

      final testAuthService = AuthServiceImpl(
        authenticationApiClient: mockAuthenticationApiClient,
        userApiClient: mockUserApiClient,
        credentialsProvider: mockCredentialsProvider,
        eventBus: mockEventBus,
      );

      // Setup login response
      when(mockBasicDio.post(any, data: anyNamed('data'))).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/api/v1/auth/login'),
          data: {
            'access_token': 'test-access-token',
            'refresh_token': 'test-refresh-token',
            'user_id': 'test-user-id',
          },
          statusCode: 200,
        ),
      );

      // Call login (which should use mockBasicDio via AuthenticationApiClient)
      await testAuthService.login('test@example.com', 'password');

      // Verify basicDio was used for login
      verify(mockBasicDio.post(any, data: anyNamed('data'))).called(1);
      verifyNever(mockAuthenticatedDio.post(any, data: anyNamed('data')));

      // Setup getUserProfile response in authenticatedDio
      when(
        mockCredentialsProvider.getUserId(),
      ).thenAnswer((_) async => 'test-user-id');
      when(mockAuthenticatedDio.get(any)).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/api/v1/users/profile'),
          data: {
            'id': 'test-user-id',
            'email': 'test@example.com',
            'name': 'Test User',
            'settings': null,
          },
          statusCode: 200,
        ),
      );

      // Set up the basicDio to fail if it's used for profile
      when(
        mockBasicDio.get(any),
      ).thenThrow(Exception('basicDio should not be used'));

      // Try to get profile (should throw for now in this test)
      // The important part is verifying the correct client was used
      try {
        await testAuthService.getUserProfile();
      } catch (_) {
        // Ignore error, just check which Dio was called
      }

      // Verify authenticatedDio was used for getUserProfile (even if it failed)
      verify(mockAuthenticatedDio.get(any)).called(1);
      verifyNever(mockBasicDio.get(any));

      // This test verifies that login uses BasicDio via AuthenticationApiClient
      // and getUserProfile uses AuthenticatedDio via UserApiClient
    });
  });
}
