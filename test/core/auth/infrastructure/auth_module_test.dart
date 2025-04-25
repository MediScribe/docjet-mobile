import 'package:dio/dio.dart';
import 'package:docjet_mobile/core/auth/auth_credentials_provider.dart';
import 'package:docjet_mobile/core/auth/auth_service.dart';
import 'package:docjet_mobile/core/auth/events/auth_event_bus.dart';
import 'package:docjet_mobile/core/auth/infrastructure/auth_api_client.dart';
import 'package:docjet_mobile/core/auth/infrastructure/auth_module.dart';
import 'package:docjet_mobile/core/auth/infrastructure/auth_service_impl.dart';
import 'package:docjet_mobile/core/auth/utils/jwt_validator.dart';
import 'package:docjet_mobile/core/auth/infrastructure/dio_factory.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:docjet_mobile/core/utils/log_helpers.dart';

// Generate mocks for dependencies needed by AuthModule constructor and registration
import 'auth_module_test.mocks.dart'; // Import generated mocks

// Create test-specific logger
final _logger = LoggerFactory.getLogger('AuthModuleTest');
final _tag = logTag('AuthModuleTest');

/// Helper method to trigger lazy resolution of authenticatedDio
Dio _resolveAuthenticatedDio(GetIt getIt) {
  _logger.d('$_tag Resolving authenticatedDio to trigger lazy factory...');
  final dio = getIt<Dio>(instanceName: 'authenticatedDio');
  _logger.d('$_tag authenticatedDio resolved: $dio');
  return dio;
}

/// Helper method to verify createAuthenticatedDio was called correctly
void _verifyAuthenticatedDioCreation(
  MockDioFactory mockDioFactory,
  MockAuthCredentialsProvider mockCredentialsProvider,
  MockAuthEventBus mockAuthEventBus,
) {
  verify(
    mockDioFactory.createAuthenticatedDio(
      authApiClient: anyNamed('authApiClient'),
      credentialsProvider: mockCredentialsProvider,
      authEventBus: mockAuthEventBus,
    ),
  ).called(1);
  _logger.d('$_tag createAuthenticatedDio() verification succeeded');
}

@GenerateMocks([
  DioFactory,
  AuthCredentialsProvider,
  AuthEventBus, // Also mock event bus for consistency
  Dio, // Mock Dio for factory return values
  AuthService, // Needed for static providerOverrides test
])
void main() {
  // Mocks for required dependencies passed via constructor
  late MockDioFactory mockDioFactory;
  late MockAuthCredentialsProvider mockCredentialsProvider;
  late MockAuthEventBus mockAuthEventBus;
  late AuthModule authModule; // Instance of the class under test

  // Mocks for dependencies potentially registered by AuthModule
  late MockDio mockBasicDio;
  late MockDio mockAuthenticatedDio;

  // GetIt instance for verification within tests
  late GetIt getIt;

  setUp(() {
    _logger.i('$_tag === SETUP STARTED ===');

    // Create mocks for constructor dependencies
    mockDioFactory = MockDioFactory();
    _logger.d('$_tag Created mockDioFactory');
    mockCredentialsProvider = MockAuthCredentialsProvider();
    _logger.d('$_tag Created mockCredentialsProvider');
    mockAuthEventBus = MockAuthEventBus();
    _logger.d('$_tag Created mockAuthEventBus');

    // Create mocks for dependencies potentially registered by AuthModule
    mockBasicDio = MockDio();
    _logger.d('$_tag Created mockBasicDio');
    mockAuthenticatedDio = MockDio();
    _logger.d('$_tag Created mockAuthenticatedDio');

    // --- Stub mockDioFactory methods used within AuthModule.register ---
    _logger.d('$_tag Setting up mockDioFactory.createBasicDio() stub');
    when(mockDioFactory.createBasicDio()).thenReturn(mockBasicDio);

    _logger.d('$_tag Setting up mockDioFactory.createAuthenticatedDio() stub');
    when(
      mockDioFactory.createAuthenticatedDio(
        // Dependencies for authenticated Dio now come from AuthModule instance
        authApiClient: anyNamed(
          'authApiClient',
        ), // AuthApiClient is created internally
        credentialsProvider: anyNamed(
          'credentialsProvider',
        ), // Match ANY credentialsProvider
        authEventBus: anyNamed('authEventBus'), // Match ANY authEventBus
      ),
    ).thenReturn(mockAuthenticatedDio);
    _logger.d('$_tag Stubs created successfully');

    // Instantiate AuthModule with explicit dependencies
    _logger.d('$_tag Creating AuthModule instance');
    authModule = AuthModule(
      dioFactory: mockDioFactory,
      credentialsProvider: mockCredentialsProvider,
      authEventBus: mockAuthEventBus,
    );
    _logger.d('$_tag AuthModule instance created');

    // Create a fresh GetIt instance ONLY for verification within each test
    _logger.d('$_tag Creating GetIt instance');
    getIt = GetIt.instance; // Use the global instance for simplicity in tests
    _logger.d('$_tag GetIt instance created');
    _logger.i('$_tag === SETUP COMPLETED ===');
  });

  tearDown(() async {
    _logger.i('$_tag === TEARDOWN STARTED ===');
    // Reset GetIt after each test to avoid interference
    await getIt.reset();
    _logger.i('$_tag GetIt has been reset');
    _logger.i('$_tag === TEARDOWN COMPLETED ===');
  });

  group('AuthModule Instance Register', () {
    test('should register all dependencies correctly when called', () {
      _logger.i(
        '$_tag TEST STARTED: should register all dependencies correctly when called',
      );

      // Act
      _logger.d('$_tag Calling authModule.register(getIt)');
      // Call the instance method; dependencies are now internal to authModule
      authModule.register(getIt);
      _logger.d('$_tag authModule.register(getIt) completed');

      // Assert: Check that AuthModule registered what it was supposed to
      _logger.d('$_tag Starting assertions to verify registrations');

      _logger.d('$_tag Verifying FlutterSecureStorage registration');
      expect(
        getIt.isRegistered<FlutterSecureStorage>(),
        isTrue,
        reason: "FlutterSecureStorage should be registered by default",
      );
      _logger.d('$_tag Verifying JwtValidator registration');
      expect(
        getIt.isRegistered<JwtValidator>(),
        isTrue,
        reason: "JwtValidator should be registered by default",
      );
      expect(
        getIt.isRegistered<AuthApiClient>(),
        isTrue,
        reason: "AuthApiClient should be registered",
      );
      expect(
        getIt.isRegistered<AuthService>(),
        isTrue,
        reason: "AuthService should be registered",
      );
      expect(
        getIt.isRegistered<Dio>(instanceName: 'basicDio'),
        isTrue,
        reason: "basicDio should be registered",
      );
      expect(
        getIt.isRegistered<Dio>(instanceName: 'authenticatedDio'),
        isTrue,
        reason: "authenticatedDio should be registered",
      );

      // Verify that the register method used the dependencies passed via constructor
      _logger.d('$_tag Verifying createBasicDio() was called');
      verify(mockDioFactory.createBasicDio()).called(1);
      _logger.d('$_tag createBasicDio() verification succeeded');

      _logger.d(
        '$_tag Attempting to verify createAuthenticatedDio() was called',
      );
      // Force the lazy singleton to be resolved, which will trigger the factory function
      _resolveAuthenticatedDio(getIt);

      // Now the factory should have been called
      _verifyAuthenticatedDioCreation(
        mockDioFactory,
        mockCredentialsProvider,
        mockAuthEventBus,
      );

      // We can't use verifyNever with GetIt since it's not a mock
      _logger.d('$_tag Skipping GetIt.get verifications - GetIt is not a mock');

      _logger.i(
        '$_tag TEST COMPLETED: should register all dependencies correctly when called',
      );
    });

    test('should resolve dependencies with correct types', () {
      _logger.i(
        '$_tag TEST STARTED: should resolve dependencies with correct types',
      );

      // Arrange
      authModule.register(getIt);

      // Act & Assert
      // Check types of registered components
      expect(getIt<AuthService>(), isA<AuthServiceImpl>());
      expect(
        getIt<Dio>(instanceName: 'basicDio'),
        isA<MockDio>(),
      ); // Comes from mocked factory
      expect(
        getIt<Dio>(instanceName: 'authenticatedDio'),
        isA<MockDio>(), // Comes from mocked factory
      );
      expect(getIt<JwtValidator>(), isA<JwtValidator>());
      expect(getIt<FlutterSecureStorage>(), isA<FlutterSecureStorage>());
      expect(getIt<AuthApiClient>(), isA<AuthApiClient>());

      // Verify dependencies passed via constructor are NOT resolved via GetIt
      // unless explicitly registered (which they shouldn't be)
      expect(getIt.isRegistered<AuthCredentialsProvider>(), isFalse);
      expect(getIt.isRegistered<AuthEventBus>(), isFalse);
      expect(getIt.isRegistered<DioFactory>(), isFalse);

      // Also verify factory methods were called as expected during registration
      verify(mockDioFactory.createBasicDio()).called(1);

      // Force the lazy singleton to be resolved, which will trigger the factory function
      _resolveAuthenticatedDio(getIt);

      // Use the same lenient verification as in the first test
      _verifyAuthenticatedDioCreation(
        mockDioFactory,
        mockCredentialsProvider,
        mockAuthEventBus,
      );

      _logger.i(
        '$_tag TEST COMPLETED: should resolve dependencies with correct types',
      );
    });

    // Test for the static providerOverrides method remains unchanged
    test('should create provider overrides', () {
      // Arrange: Minimal registration needed just for the static method test
      // Use the main test GetIt instance, it will be reset in tearDown
      getIt.registerLazySingleton<AuthService>(() => MockAuthService());

      // Act
      final overrides = AuthModule.providerOverrides(getIt);

      // Assert
      expect(overrides, isA<List<Object>>()); // Riverpod Override is an Object
      expect(overrides.length, 1); // One override for authServiceProvider

      // No need to reset temp instance anymore
    });
  });
}

// MockAuthService is now generated by @GenerateMocks, so the manual class is removed
