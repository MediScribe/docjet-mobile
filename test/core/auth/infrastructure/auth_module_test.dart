import 'package:dio/dio.dart';
import 'package:docjet_mobile/core/auth/auth_credentials_provider.dart';
import 'package:docjet_mobile/core/auth/auth_service.dart';
import 'package:docjet_mobile/core/auth/events/auth_event_bus.dart';
import 'package:docjet_mobile/core/auth/infrastructure/auth_api_client.dart';
import 'package:docjet_mobile/core/auth/infrastructure/auth_module.dart';
import 'package:docjet_mobile/core/auth/infrastructure/auth_service_impl.dart';
import 'package:docjet_mobile/core/auth/secure_storage_auth_credentials_provider.dart';
import 'package:docjet_mobile/core/auth/utils/jwt_validator.dart';
import 'package:docjet_mobile/core/config/app_config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mockito/mockito.dart';

// Create mock for AuthEventBus
class MockAuthEventBus extends Mock implements AuthEventBus {}

void main() {
  late GetIt getIt;
  late AppConfig mockAppConfig;

  setUp(() {
    // Create a new GetIt instance for each test
    getIt = GetIt.asNewInstance();

    // Create mock AppConfig for testing
    mockAppConfig = AppConfig.test(
      apiDomain: 'test.example.com',
      apiKey: 'test-key',
    );

    // Register AuthEventBus before running AuthModule.register
    getIt.registerLazySingleton<AuthEventBus>(() => MockAuthEventBus());
  });

  tearDown(() async {
    // Reset GetIt after each test
    await getIt.reset();
  });

  group('AuthModule', () {
    test('should register all dependencies correctly', () {
      // Act
      AuthModule.register(getIt, mockAppConfig: mockAppConfig);

      // Assert
      expect(getIt.isRegistered<FlutterSecureStorage>(), isTrue);
      expect(getIt.isRegistered<AuthCredentialsProvider>(), isTrue);
      expect(getIt.isRegistered<AuthApiClient>(), isTrue);
      expect(getIt.isRegistered<AuthService>(), isTrue);
      expect(getIt.isRegistered<Dio>(instanceName: 'basicDio'), isTrue);
      expect(getIt.isRegistered<Dio>(instanceName: 'authenticatedDio'), isTrue);
      expect(getIt.isRegistered<AuthEventBus>(), isTrue);
      expect(getIt.isRegistered<JwtValidator>(), isTrue);
    });

    test('should resolve dependencies with correct types', () {
      // Arrange
      AuthModule.register(getIt, mockAppConfig: mockAppConfig);

      // Act & Assert
      expect(
        getIt<AuthCredentialsProvider>(),
        isA<SecureStorageAuthCredentialsProvider>(),
      );
      expect(getIt<AuthService>(), isA<AuthServiceImpl>());
      expect(getIt<Dio>(instanceName: 'basicDio'), isA<Dio>());
      expect(getIt<Dio>(instanceName: 'authenticatedDio'), isA<Dio>());
      expect(getIt<AuthEventBus>(), isA<MockAuthEventBus>());
      expect(getIt<JwtValidator>(), isA<JwtValidator>());
    });

    test('should create provider overrides', () {
      // Arrange
      AuthModule.register(getIt, mockAppConfig: mockAppConfig);

      // Act
      final overrides = AuthModule.providerOverrides(getIt);

      // Assert
      expect(overrides, isA<List<Override>>());
      expect(overrides.length, 1); // One override for authServiceProvider
    });
  });
}
