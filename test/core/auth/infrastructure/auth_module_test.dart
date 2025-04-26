import 'package:dio/dio.dart';
import 'package:docjet_mobile/core/auth/auth_credentials_provider.dart';
import 'package:docjet_mobile/core/auth/auth_error_type.dart';
import 'package:docjet_mobile/core/auth/auth_exception.dart';
import 'package:docjet_mobile/core/auth/auth_service.dart';
import 'package:docjet_mobile/core/auth/events/auth_event_bus.dart';
import 'package:docjet_mobile/core/auth/infrastructure/auth_api_client.dart';
import 'package:docjet_mobile/core/auth/infrastructure/auth_module.dart';
import 'package:docjet_mobile/core/auth/infrastructure/dio_factory.dart';
import 'package:docjet_mobile/core/auth/utils/jwt_validator.dart';
import 'package:docjet_mobile/core/config/api_config.dart';
import 'package:docjet_mobile/core/utils/log_helpers.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

// Generate mocks for dependencies needed by AuthModule constructor and registration
@GenerateMocks([
  AuthCredentialsProvider,
  AuthEventBus,
  DioFactory,
  Dio, // Mock Dio for factory return values
  AuthService, // Needed for static providerOverrides test
  FlutterSecureStorage,
  JwtValidator,
])
import 'auth_module_test.mocks.dart';

void main() {
  // Set up logger for this test file
  final logger = LoggerFactory.getLogger('AuthModuleTest');
  final tag = logTag('AuthModuleTest');

  // Test dependencies
  late MockDioFactory mockDioFactory;
  late MockAuthCredentialsProvider mockCredentialsProvider;
  late MockAuthEventBus mockEventBus;
  late MockDio mockBasicDio;
  late MockDio mockAuthenticatedDio;
  late MockFlutterSecureStorage mockSecureStorage;
  late MockJwtValidator mockJwtValidator;

  // Module to test
  late AuthModule authModule;

  // GetIt instance for verification within tests
  late GetIt getIt;

  const testAccessToken = 'test-access-token';

  setUp(() {
    logger.i('$tag Setting up test dependencies');

    // Create a fresh GetIt instance for each test
    getIt = GetIt.instance;
    getIt.reset();

    // Set up test dependencies
    logger.d('$tag Creating mock instances');
    mockDioFactory = MockDioFactory();
    mockCredentialsProvider = MockAuthCredentialsProvider();
    mockEventBus = MockAuthEventBus();
    mockBasicDio = MockDio();
    mockAuthenticatedDio = MockDio();
    mockSecureStorage = MockFlutterSecureStorage();
    mockJwtValidator = MockJwtValidator();

    // Configure mockDioFactory to return our mocks
    logger.d('$tag Setting up stubs for mock DioFactory');
    when(mockDioFactory.createBasicDio()).thenReturn(mockBasicDio);
    when(
      mockDioFactory.createAuthenticatedDio(
        authApiClient: anyNamed('authApiClient'),
        credentialsProvider: anyNamed('credentialsProvider'),
        authEventBus: anyNamed('authEventBus'),
      ),
    ).thenReturn(mockAuthenticatedDio);

    logger.d('$tag Stubs created successfully');

    // Setup credential provider to return a token
    when(
      mockCredentialsProvider.getAccessToken(),
    ).thenAnswer((_) async => testAccessToken);

    // Instantiate AuthModule with explicit dependencies
    logger.d('$tag Creating AuthModule instance');
    authModule = AuthModule(
      dioFactory: mockDioFactory,
      credentialsProvider: mockCredentialsProvider,
      authEventBus: mockEventBus,
    );
  });

  tearDown(() {
    logger.i('$tag Tearing down...');
    getIt.reset();
  });

  group('Registration', () {
    test('should register all core components in correct order', () async {
      // Act
      logger.d('$tag Running registration');
      authModule.register(getIt);

      // Assert
      expect(getIt.isRegistered<Dio>(instanceName: 'basicDio'), isTrue);
      expect(getIt.isRegistered<AuthApiClient>(), isTrue);
      expect(getIt.isRegistered<Dio>(instanceName: 'authenticatedDio'), isTrue);
      expect(getIt.isRegistered<AuthService>(), isTrue);

      // Verify the registration order by examining invocation order
      logger.d('$tag Verifying call order');
      verifyInOrder([
        // Step 1: Create basic Dio first
        mockDioFactory.createBasicDio(),
        // Step 3: Create authenticated Dio after API client is available
        mockDioFactory.createAuthenticatedDio(
          authApiClient: anyNamed('authApiClient'),
          credentialsProvider: anyNamed('credentialsProvider'),
          authEventBus: anyNamed('authEventBus'),
        ),
      ]);
    });

    test('should not re-register already registered components', () async {
      // Arrange
      logger.d('$tag Pre-registering basicDio for duplicate test');
      getIt.registerSingleton<Dio>(mockBasicDio, instanceName: 'basicDio');

      // Act
      logger.d('$tag Running registration with pre-registered component');
      authModule.register(getIt);

      // Assert - should not try to create a new basicDio
      verifyNever(mockDioFactory.createBasicDio());
    });
  });

  group('Riverpod Integration', () {
    test('providerOverrides should include auth service provider', () {
      // Arrange
      logger.d('$tag Setting up GetIt for provider overrides test');
      final mockAuthService = MockAuthService();
      getIt.registerSingleton<AuthService>(mockAuthService);

      // Act
      logger.d('$tag Getting provider overrides');
      final overrides = AuthModule.providerOverrides(getIt);

      // Assert
      logger.d('$tag Verifying overrides contain authServiceProvider');
      expect(overrides.length, greaterThan(0));
    });
  });

  test('getUserProfile needs AuthInterceptor to add JWT token', () async {
    // Arrange: Register components with the auth module
    authModule.register(
      getIt,
      secureStorage: mockSecureStorage,
      jwtValidator: mockJwtValidator,
    );

    // Access the registered components
    final authApiClient = getIt<AuthApiClient>();

    // Set expectations for the basic Dio (missing Authorization header)
    when(mockBasicDio.get(any)).thenThrow(
      DioException(
        requestOptions: RequestOptions(path: ApiConfig.userProfileEndpoint),
        response: Response(
          statusCode: 401,
          data: {'error': 'Missing or invalid Authorization header'},
          requestOptions: RequestOptions(path: ApiConfig.userProfileEndpoint),
        ),
        type: DioExceptionType.badResponse,
      ),
    );

    // Set expectations for authenticated Dio (includes Authorization header)
    when(mockAuthenticatedDio.get(any)).thenAnswer(
      (_) async => Response(
        statusCode: 200,
        data: {'id': 'user-id', 'name': 'Test User'},
        requestOptions: RequestOptions(path: ApiConfig.userProfileEndpoint),
      ),
    );

    // Act & Assert - getUserProfile() should fail with basic Dio
    expect(
      () => authApiClient.getUserProfile(),
      throwsA(
        isA<AuthException>().having(
          (e) => e.type,
          'type',
          equals(AuthErrorType.userProfileFetchFailed),
        ),
      ),
    );

    // Verify basicDio was used and authenticatedDio was not used
    verify(mockBasicDio.get(any)).called(1);
    verifyNever(mockAuthenticatedDio.get(any));
  });

  test(
    'Fixed AuthApiClient uses authenticatedDio for profile requests',
    () async {
      // Arrange: Register components
      authModule.register(
        getIt,
        secureStorage: mockSecureStorage,
        jwtValidator: mockJwtValidator,
      );

      // Replace the AuthApiClient with one that uses authenticatedDio
      getIt.unregister<AuthApiClient>();
      getIt.registerSingleton<AuthApiClient>(
        AuthApiClient(
          httpClient: getIt<Dio>(instanceName: 'authenticatedDio'),
          credentialsProvider: mockCredentialsProvider,
        ),
      );

      // Get the fixed API client
      final fixedAuthApiClient = getIt<AuthApiClient>();

      // Set expectations for authenticated Dio (includes Authorization header correctly)
      when(mockAuthenticatedDio.get(any)).thenAnswer(
        (_) async => Response(
          statusCode: 200,
          data: {'id': 'user-id', 'name': 'Test User'},
          requestOptions: RequestOptions(path: ApiConfig.userProfileEndpoint),
        ),
      );

      // Act - Call getUserProfile with the fixed API client
      await fixedAuthApiClient.getUserProfile();

      // Assert - authenticatedDio should be used, not basicDio
      verifyNever(mockBasicDio.get(any));
      verify(mockAuthenticatedDio.get(any)).called(1);
    },
  );
}
