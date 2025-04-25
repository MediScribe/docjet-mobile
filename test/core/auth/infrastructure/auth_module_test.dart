import 'package:dio/dio.dart';
import 'package:docjet_mobile/core/auth/auth_credentials_provider.dart';
import 'package:docjet_mobile/core/auth/auth_service.dart';
import 'package:docjet_mobile/core/auth/events/auth_event_bus.dart';
import 'package:docjet_mobile/core/auth/infrastructure/auth_api_client.dart';
import 'package:docjet_mobile/core/auth/infrastructure/auth_module.dart';
import 'package:docjet_mobile/core/auth/infrastructure/auth_service_impl.dart';
import 'package:docjet_mobile/core/auth/utils/jwt_validator.dart';
import 'package:docjet_mobile/core/auth/infrastructure/dio_factory.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

// Generate mocks for dependencies needed by AuthModule.register
import 'auth_module_test.mocks.dart'; // Import generated mocks

@GenerateMocks([
  DioFactory,
  AuthCredentialsProvider,
  AuthEventBus, // Also mock event bus for consistency
  Dio, // Mock Dio for factory return values
])
void main() {
  late GetIt getIt;
  late AuthModule authModule; // Instance of the class under test
  // Mocks for required dependencies
  late MockDioFactory mockDioFactory;
  late MockAuthCredentialsProvider mockCredentialsProvider;
  late MockAuthEventBus mockAuthEventBus;
  // Mocks for dependencies potentially registered by AuthModule
  late MockDio mockBasicDio;
  late MockDio mockAuthenticatedDio;

  setUp(() {
    // Create mocks
    mockDioFactory = MockDioFactory();
    mockCredentialsProvider = MockAuthCredentialsProvider();
    mockAuthEventBus = MockAuthEventBus();
    mockBasicDio = MockDio();
    mockAuthenticatedDio = MockDio();

    // Create a new GetIt instance for each test
    getIt = GetIt.asNewInstance();

    // Create the AuthModule instance
    authModule = AuthModule();

    // --- Stub mockDioFactory methods ---
    when(mockDioFactory.createBasicDio()).thenReturn(mockBasicDio);
    when(
      mockDioFactory.createAuthenticatedDio(
        authApiClient: anyNamed('authApiClient'),
        credentialsProvider: anyNamed('credentialsProvider'),
        authEventBus: anyNamed('authEventBus'),
      ),
    ).thenReturn(mockAuthenticatedDio);

    // Register the mock AuthEventBus beforehand, as AuthModule expects it
    // (or receives it as a parameter)
    getIt.registerLazySingleton<AuthEventBus>(() => mockAuthEventBus);
    // It's important that AuthCredentialsProvider is also pre-registered or provided
    // because AuthModule needs it but doesn't register it itself.
    getIt.registerLazySingleton<AuthCredentialsProvider>(
      () => mockCredentialsProvider,
    );
  });

  tearDown(() async {
    // Reset GetIt after each test
    await getIt.reset();
  });

  group('AuthModule Instance Register', () {
    test('should register all dependencies correctly when called', () {
      // Act
      // Call the instance method with required mocks
      authModule.register(
        getIt,
        dioFactory: mockDioFactory,
        credentialsProvider:
            mockCredentialsProvider, // Use the pre-registered mock
        authEventBus: mockAuthEventBus, // Use the pre-registered mock
        // Optional dependencies left null to test default registration
      );

      // Assert: Check that AuthModule registered what it was supposed to
      expect(
        getIt.isRegistered<FlutterSecureStorage>(),
        isTrue,
        reason: "FlutterSecureStorage should be registered by default",
      );
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
      // Verify the *provided* dependencies are still registered
      expect(
        getIt.isRegistered<AuthCredentialsProvider>(),
        isTrue,
        reason: "AuthCredentialsProvider should remain registered",
      );
      expect(
        getIt.isRegistered<AuthEventBus>(),
        isTrue,
        reason: "AuthEventBus should remain registered",
      );
    });

    test('should resolve dependencies with correct types', () {
      // Arrange
      authModule.register(
        getIt,
        dioFactory: mockDioFactory,
        credentialsProvider: mockCredentialsProvider,
        authEventBus: mockAuthEventBus,
      );

      // Act & Assert
      // Check types of DEFAULT registered components
      expect(
        getIt<AuthCredentialsProvider>(),
        isA<MockAuthCredentialsProvider>(), // Should be the mock we provided
      );
      expect(getIt<AuthService>(), isA<AuthServiceImpl>());
      // Check types of components created using the MOCKED DioFactory
      expect(getIt<Dio>(instanceName: 'basicDio'), isA<MockDio>());
      expect(getIt<Dio>(instanceName: 'authenticatedDio'), isA<MockDio>());
      // Check types of provided/pre-registered components
      expect(getIt<AuthEventBus>(), isA<MockAuthEventBus>());
      // Check types of default registered components
      expect(getIt<JwtValidator>(), isA<JwtValidator>());
      expect(getIt<FlutterSecureStorage>(), isA<FlutterSecureStorage>());
    });

    // Test for the static providerOverrides method remains unchanged
    test('should create provider overrides', () {
      // Arrange: Register necessary dependencies for providerOverrides to work
      // Minimal registration needed just for the static method test
      getIt.registerLazySingleton<AuthService>(
        () => MockAuthService(),
      ); // Need an AuthService

      // Act
      final overrides = AuthModule.providerOverrides(getIt);

      // Assert
      expect(overrides, isA<List<Override>>());
      expect(overrides.length, 1); // One override for authServiceProvider
    });
  });
}

// Define MockAuthService needed for the static providerOverrides test
class MockAuthService extends Mock implements AuthService {}
